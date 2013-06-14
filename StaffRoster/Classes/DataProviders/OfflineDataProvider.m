//
//  OfflineDataProvider.m
//  StaffRoster
//
//  Created by yavuz on 6/12/13.
//  Copyright (c) 2013 redhat. All rights reserved.
//

#import "OfflineDataProvider.h"
#import "StaffRosterAPIClient.h"

@implementation OfflineDataProvider

+ (NSArray *)getEmployees:(NSString *)query {
    return [[self getEmployeesDataStore] filter:[NSPredicate predicateWithFormat:@"cn BEGINSWITH[cd] %@", query]];
}

+ (NSArray *)getManager:(NSString *)query {
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

+ (NSArray *)getColleagues:(NSString *)query {
    id employee = [self getEmployees:query];
    if (!employee || ![employee count]) {
        return nil;
    }
    return [self getEmployeesByManager:[[employee objectAtIndex:0] objectForKey:@"manager"]];
}

+ (NSArray *)getDReports:(NSString *)query {
    id employee = [self getEmployees:query];
    if (!employee || ![employee count]) {
        return nil;
    }
    return [[self getEmployeesDataStore] filter:[NSPredicate predicateWithFormat:@"manager = %@", [NSString stringWithFormat:@"uid=%@,%@", [[employee objectAtIndex:0] objectForKey:@"uid"], kManagerFilterFields]]];
}

+ (NSInteger)getDReportsCount:(NSString *)query {
    return [[self getDReports:query] count];
}

+ (NSArray *)getAllData {
    return [[self getEmployeesDataStore] readAll];
}

#pragma mark - data sync methods

+ (void)syncDataProvider {
    [[StaffRosterAPIClient sharedInstance].syncCheckPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"last_sync_date": [self getLastSyncTime]}] success:^(id responseObject) {
        NSLog(@"Sync response obj: %@", responseObject);
        if ([[[responseObject objectAtIndex:0] objectForKey:@"sync_required"] isEqual:@"true"]) {
            dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
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

+ (void)reloadEmployeeDataStore {
    [[StaffRosterAPIClient sharedInstance].offlineDataPipe read:^(id responseObject) {
        // update table with the newly fetched data
        // !!!: handle when reset is not successful, should we really loose what we have loaded?
        dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSLog(@"Offline Data: %@", responseObject);
            if ([self resetEmployeesStore]) {
                if([self saveToEmployeesStore:responseObject]) {
                    // everything is successful, so timestamp last sync time
                    // !!!: what if there is a new update on server side between syncCheckTime (send req through syncCheckPipe) and syncCompleteTime (update local data store - i.e now)?
                    [self setLastSyncTimeToNow];
                }
            }
        });
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
    }];
}

#pragma mark - utility methods

+ (id<AGStore>)getEmployeesDataStore {
    return [self getDataStore:@"employees" withType:@"PLIST"];
}

+ (id<AGStore>)getSyncTimeDataStore {
    return [self getDataStore:@"sync_time" withType:@"PLIST"];
}

+ (NSString *)getLastSyncTime {
    if ([[self getSyncTimeDataStore] read:@"1"]) {
        return [[NSString alloc] initWithFormat:@"%@", [[[self getSyncTimeDataStore] read:@"1"] objectForKey:@"last_sync_time"]];
    } else {
        return @"0";
    }
}

+ (void)setLastSyncTimeToNow {
    [[self getSyncTimeDataStore] save:@{@"last_sync_time": [[NSString alloc] initWithFormat:@"%f", ([[NSDate date] timeIntervalSince1970])], @"id": @"1"} error:nil];
}

+ (id<AGStore>)getDataStore:(NSString *)storeName withType:(NSString *)storeType {
    return [[AGDataManager manager] store:^(id<AGStoreConfig> config) {
        [config setName:storeName];
        [config setType:storeType];
    }];
}

+ (NSArray *)getEmployeesByUID:(NSString *)uid { // yes, it is employee"s" to indicate it returns an array of employees (which actually contains a single employee)
    return [[self getEmployeesDataStore] filter:[NSPredicate predicateWithFormat:@"uid = %@", uid]];
}

+ (NSArray *)getEmployeesByManager:(NSString *)manager {
    return [[self getEmployeesDataStore] filter:[NSPredicate predicateWithFormat:@"manager = %@", manager]];
}

// use with caution!!!
+ (bool)resetEmployeesStore {
    NSError *error;
    if(![[self getEmployeesDataStore] reset:&error]){
        NSLog(@"Store Reset Error: %@", error);
        return false;
    }
    return true;
}

+ (bool)saveToEmployeesStore:(id)responseObject {
    NSError *error;
    if (![[self getEmployeesDataStore] save:[self unNullifyResponse:responseObject] error:&error]){
        NSLog(@"Save: An error occured during save! \n%@", error);
        return false;
    }
    return true;
}

+ (NSArray *)unNullifyResponse:(NSArray *)response {
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
