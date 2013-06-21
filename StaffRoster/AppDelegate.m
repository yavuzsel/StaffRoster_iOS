//
//  AppDelegate.m
//  StaffRoster
//
//  Created by yavuz on 5/23/13.
//  Copyright (c) 2013 redhat. All rights reserved.
//

#import "EmployeeSearchViewController.h"
#import "AppDelegate.h"
#import "OfflineDataProvider.h"
#import "StaffDetailTableViewController.h"
#import "StaffRosterAPIClient.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    EmployeeSearchViewController *searchViewController = [[EmployeeSearchViewController alloc] initWithStyle:UITableViewStyleGrouped];
    searchViewController.pageType = kEmployeeSearchViewPageTypeSearch;
    UINavigationController *searchNavigation = [[UINavigationController alloc] initWithRootViewController:searchViewController];
    searchNavigation.navigationBarHidden = YES;
    searchNavigation.navigationBar.tintColor = kAppTintColor;
    searchNavigation.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:0];
    
    StaffDetailTableViewController *profileViewController = [[StaffDetailTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    
    // TODO: this part (i.e. setting user for profile page) is gonna change when we introduce the login
    id employeeInList = [[OfflineDataProvider sharedInstance] getEmployeesByUID:kDefaultAppUserUID];
    if (employeeInList && [employeeInList count]) {
        profileViewController.employee = [employeeInList objectAtIndex:0];
    } else {
        [[StaffRosterAPIClient sharedInstance].employeesPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"query": kDefaultAppUserCN}] success:^(id responseObject) {
            if ([responseObject count]) {
                profileViewController.employee = [responseObject objectAtIndex:0];
            }            
        } failure:^(NSError *error) {
            NSLog(@"An error has occured during profile read! \n%@", error);
        }];
    }
    
    UINavigationController *profileNavigation = [[UINavigationController alloc] initWithRootViewController:profileViewController];
    profileNavigation.navigationBar.tintColor = kAppTintColor;
    profileNavigation.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemContacts tag:1];

    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.tabBar.tintColor = kAppTintColor;
    tabBarController.viewControllers = [NSArray arrayWithObjects:searchNavigation, profileNavigation, nil];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = tabBarController;

    [self.window makeKeyAndVisible];
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[OfflineDataProvider sharedInstance] syncDataProvider];
        //NSLog(@"Data: %@", [[OfflineDataProvider sharedInstance] getAllData]);
    });
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
