//
//  OfflineDataProvider.h
//  StaffRoster
//
//  Created by yavuz on 6/12/13.
//  Copyright (c) 2013 redhat. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "StaffRosterAPIClient.h"

@interface OfflineDataProvider : NSObject

+ (OfflineDataProvider *)sharedInstance;

@property AGDataManager *dManager;
@property id<AGStore> employeeStore;
@property id<AGStore> syncTimeStore;

- (NSArray *)getEmployees:(NSString *)query;
- (NSArray *)getManager:(NSString *)query;
- (NSArray *)getColleagues:(NSString *)query;
- (NSInteger)getColleaguesCount:(NSString *)query;
- (NSArray *)getDReports:(NSString *)query;
- (NSInteger)getDReportsCount:(NSString *)query;
- (NSArray *)getEmployeesByUID:(NSString *)uid;
- (void)syncDataProvider;

- (NSArray *)getAllData;
- (bool)isDataExist;

- (bool)setProfileImagePath:(NSString *)imgPath toEmployee:(id)employee;
- (NSString *)getProfileImagePath:(id)employee;

@end
