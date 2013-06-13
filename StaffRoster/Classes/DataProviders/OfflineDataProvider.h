//
//  OfflineDataProvider.h
//  StaffRoster
//
//  Created by yavuz on 6/12/13.
//  Copyright (c) 2013 redhat. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OfflineDataProvider : NSObject

+ (NSArray *)getEmployees:(NSString *)query;
+ (NSArray *)getManager:(NSString *)query;
+ (NSArray *)getColleagues:(NSString *)query;
+ (NSArray *)getDReports:(NSString *)query;
+ (NSInteger)getDReportsCount:(NSString *)query;
+ (void)syncDataProvider;

@end
