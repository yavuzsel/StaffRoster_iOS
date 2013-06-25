//
//  RHLocation.m
//  StaffRoster
//
//  Created by yavuz on 6/24/13.
//  Copyright (c) 2013 redhat. All rights reserved.
//

#import "RHLocation.h"

@implementation RHLocation

@synthesize locName = _locName;
@synthesize employeeList = _employeeList;

- (id)init {
    if (self = [super init]) {
        self.employeeList = [[NSMutableArray alloc] init];
    }
    return self;
}

@end
