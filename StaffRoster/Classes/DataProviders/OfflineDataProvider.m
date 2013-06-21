//
//  OfflineDataProvider.m
//  StaffRoster
//
//  Created by yavuz on 6/12/13.
//  Copyright (c) 2013 redhat. All rights reserved.
//

/*
 * not so efficient. either developer or AeroGear DataManager should implement async operations
 *
 */

#import "OfflineDataProvider.h"

@implementation OfflineDataProvider

@synthesize dManager = _dManager;
@synthesize employeeStore = _employeeStore;
@synthesize syncTimeStore = _syncTimeStore;

+ (OfflineDataProvider *)sharedInstance {
    static OfflineDataProvider *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (id)init {
    if (self = [super init]) {
        _dManager = [AGDataManager manager];
        _employeeStore = [_dManager store:^(id<AGStoreConfig> config) {
            [config setName:@"employees"];
            [config setType:@"PLIST"];
        }];
        _syncTimeStore = [_dManager store:^(id<AGStoreConfig> config) {
            [config setName:@"sync_time"];
            [config setType:@"PLIST"];
        }];
    }
    return self;
}

- (NSArray *)getEmployees:(NSString *)query {
    return [[self getEmployeesDataStore] filter:[NSPredicate predicateWithFormat:@"cn BEGINSWITH[cd] %@", query]];
}

- (NSArray *)getManager:(NSString *)query {
    id employee = [self getEmployees:query];
    if (!employee || ![employee count]) {
        return nil;
    }
    if (![[[employee objectAtIndex:0] objectForKey:@"manager"] length]) {
        // sb doesn't have a manager. CEO?
        return nil;
    }
    // this is so dependent on manager field format. make sure this works if it changes.
    return [self getEmployeesByUID:[[[[[[employee objectAtIndex:0] objectForKey:@"manager"] componentsSeparatedByString:@","] objectAtIndex:0] componentsSeparatedByString:@"="] objectAtIndex:1]];
}

- (NSArray *)getColleagues:(NSString *)query {
    id employee = [self getEmployees:query];
    if (!employee || ![employee count]) {
        return nil;
    }
    if (![[employee objectAtIndex:0] objectForKey:@"manager"] || ![[[employee objectAtIndex:0] objectForKey:@"manager"] length]) {
        return [NSArray array];
    }
    return [self getEmployeesByManager:[[employee objectAtIndex:0] objectForKey:@"manager"]];
}

- (NSInteger)getColleaguesCount:(NSString *)query {
    return [[self getColleagues:query] count];
}

- (NSArray *)getDReports:(NSString *)query {
    id employee = [self getEmployees:query];
    if (!employee || ![employee count]) {
        return nil;
    }
    return [[self getEmployeesDataStore] filter:[NSPredicate predicateWithFormat:@"manager = %@", [NSString stringWithFormat:@"uid=%@,%@", [[employee objectAtIndex:0] objectForKey:@"uid"], kManagerFilterFields]]];
}

- (NSInteger)getDReportsCount:(NSString *)query {
    return [[self getDReports:query] count];
}

- (NSArray *)getAllData {
    return [[self getEmployeesDataStore] readAll];
}

#pragma mark - data sync methods

- (void)syncDataProvider {
    [[StaffRosterAPIClient sharedInstance].syncCheckPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"last_sync_date": [self getLastSyncTime]}] success:^(id responseObject) {
        NSLog(@"Sync response obj: %@", responseObject);
        if ([[[responseObject objectAtIndex:0] objectForKey:@"sync_required"] isEqual:@"true"]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self reloadEmployeeDataStore];
            });
        } else {
            // no need to sync
            //NSLog(@"NO SYNC: %@", [self getAllData]);
            NSLog(@"Last Synced: %@", [self getLastSyncTime]);
        }
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
        NSLog(@"Last Synced: %@", [self getLastSyncTime]);
    }];
}

- (void)reloadEmployeeDataStore {
    // read with sync time from this pipe too to receive only the new updates. sync_time = 0 -> readAll
    [[StaffRosterAPIClient sharedInstance].offlineDataPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"last_sync_date": [self getLastSyncTime]}] success:^(id responseObject) {
        // update table with the newly fetched data
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSLog(@"Offline Data: %@", responseObject);
            // if save is interrupted, same data will be downloaded again and again until the success is timestamped.
            // is it the best solution?
            if([self saveToEmployeesStore:[[responseObject objectAtIndex:0] objectForKey:@"records"]]) {
                // everything is successful, so timestamp last sync time
                // !!!: what if there is a new update on server side between syncCheckTime (send req through syncCheckPipe) and syncCompleteTime (update local data store - i.e now)?
                [self setLastSyncTimeToNow];
                // remove uids --- best effort?
                if([self removeFromEmployeesStore:[[responseObject objectAtIndex:0] objectForKey:@"uids"]]) {
                    NSLog(@"Reload Completed Successfully!!!");
                } else {
                    NSLog(@"Reload Completed (Remove Error)!!!");
                }
            }
        });
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
    }];
}

#pragma mark - profile image stuff
// we might need to remove this stuff soon (image part is still under heavy development)

- (bool)setProfileImagePath:(NSString *)imgPath toEmployee:(id)employee {
    id employeeToSave = [employee mutableCopy];
    [employeeToSave setObject:imgPath forKey:@"profile_image_path"];
    return [self saveToEmployeesStore:[NSArray arrayWithObject:employeeToSave]];
}

- (NSString *)getProfileImagePath:(id)employee {
    return [[[self getEmployeesByUID:[employee objectForKey:@"uid"]] objectAtIndex:0] objectForKey:@"profile_image_path"];
}

#pragma mark - utility methods

- (id<AGStore>)getEmployeesDataStore {
    return _employeeStore;//[self getDataStore:@"employees" withType:@"PLIST"];
}

- (id<AGStore>)getSyncTimeDataStore {
    return _syncTimeStore;//[self getDataStore:@"sync_time" withType:@"PLIST"];
}

- (NSString *)getLastSyncTime {
    if ([[self getSyncTimeDataStore] read:@"1"]) {
        return [[NSString alloc] initWithFormat:@"%@", [[[self getSyncTimeDataStore] read:@"1"] objectForKey:@"last_sync_time"]];
    } else {
        return @"0";
    }
}

- (void)setLastSyncTimeToNow {
    [[self getSyncTimeDataStore] save:@{@"last_sync_time": [[NSString alloc] initWithFormat:@"%f", ([[NSDate date] timeIntervalSince1970])], @"id": @"1"} error:nil];
}

- (id<AGStore>)getDataStore:(NSString *)storeName withType:(NSString *)storeType {
    return [/*[AGDataManager manager]*/_dManager store:^(id<AGStoreConfig> config) {
        [config setName:storeName];
        [config setType:storeType];
    }];
}

- (NSArray *)getEmployeesByUID:(NSString *)uid { // yes, it is employee"s" to indicate it returns an array of employees (which actually contains a single employee)
    return [[self getEmployeesDataStore] filter:[NSPredicate predicateWithFormat:@"uid = %@", uid]];
}

- (NSArray *)getEmployeesByManager:(NSString *)manager {
    return [[self getEmployeesDataStore] filter:[NSPredicate predicateWithFormat:@"manager = %@", manager]];
}

- (id)getLastID {
    NSArray *sortedIDs = [[[[self getEmployeesDataStore] readAll] valueForKey:@"id"] sortedArrayUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:NO]]];
    return ([sortedIDs count])?[sortedIDs objectAtIndex:0]:0;
}

// use with caution!!!
- (bool)resetEmployeesStore {
    NSError *error;
    if(![[self getEmployeesDataStore] reset:&error]){
        NSLog(@"Store Reset Error: %@", error);
        return false;
    }
    return true;
}

- (bool)saveToEmployeesStore:(id)recordsList {
    NSMutableArray *employeesToAdd = [[NSMutableArray alloc] init];
    NSArray *unNullifiedResponse = [self unNullifyResponse:recordsList];
    NSInteger lastID = [[self getLastID] integerValue];
    for (NSDictionary *employee in unNullifiedResponse) {
        NSArray *employeesInDataStore = [self getEmployeesByUID:[employee objectForKey:@"uid"]];
        NSMutableDictionary *employeeToSave = [employee mutableCopy];
        if ([employeesInDataStore count]) {
            [employeeToSave setValue:[[employeesInDataStore objectAtIndex:0] objectForKey:@"id"] forKey:@"id"];
        } else {
            [employeeToSave setValue:[[NSString alloc] initWithFormat:@"%d", ++lastID] forKey:@"id"];
        }
        [employeesToAdd addObject:employeeToSave];
    }
    NSLog(@"Save: %@", employeesToAdd);
    NSError *error;
    if (![[self getEmployeesDataStore] save:employeesToAdd error:&error]){
        NSLog(@"Save: An error occured during save! \n%@", error);
        return false;
    }
    return true;
}

- (bool)removeFromEmployeesStore:(id)uidsList {
    NSArray *employeesInStore = [self getAllData];
    bool success = true;
    NSError *error;
    for (id employee in employeesInStore) {
        //NSLog(@"employee: %@", employee);
        if (![uidsList containsObject:[employee objectForKey:@"uid"]]) {
            NSLog(@"Removing: %@", employee);
            if(![[self getEmployeesDataStore] remove:employee error:&error]) {
                NSLog(@"Remove: An error occured during remove! \n%@", error);
                success = false;
            }
        }
    }
    return success;
}

- (NSArray *)unNullifyResponse:(NSArray *)response {
    NSMutableArray *unNulledResponse = [[NSMutableArray alloc] init];
    NSMutableDictionary *employeeToUnNullify;
    for (NSDictionary *employee in response) {
        employeeToUnNullify = [employee mutableCopy];
        for (id key in employee) {
            if ([[employeeToUnNullify objectForKey:key] isEqual:[NSNull null]]) {
                [employeeToUnNullify setObject:[[NSData alloc] init] forKey:key];
            }
        }
        [unNulledResponse addObject:employeeToUnNullify];
    }
    return unNulledResponse;
}

@end
