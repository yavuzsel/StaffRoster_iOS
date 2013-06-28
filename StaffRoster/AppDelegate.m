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
#import <AeroGearPush.h>

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
    profileNavigation.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"My Profile" image:[UIImage imageNamed:@"profile.png"] tag:0];//[[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemContacts tag:1];

    
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.tabBar.tintColor = kAppTintColor;
    tabBarController.viewControllers = [NSArray arrayWithObjects:searchNavigation, profileNavigation, nil];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = tabBarController;

    [self.window makeKeyAndVisible];
    
    // even if the read from pipe is already async, this call requires to read from datastore which is not async. so dispatch a thread and execute there.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [[OfflineDataProvider sharedInstance] syncDataProvider];
        //NSLog(@"Data: %@", [[OfflineDataProvider sharedInstance] getAllData]);
    });
    
    return YES;
}

// Here we need to register this "Mobile Variant Instance"
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    // we init our "Registration helper:
    AGDeviceRegistration *registration =
    
    // WARNING: make sure, you start JBoss with the -b 0.0.0.0 option, to bind on all interfaces
    // from the iPhone, you can NOT use localhost :)
    [[AGDeviceRegistration alloc] initWithServerURL:[NSURL URLWithString:@"http://10.193.23.8:8080/ag-push/"]];
    
    [registration registerWithClientInfo:^(id<AGClientDeviceInformation> clientInfo) {
        
        // Use the Mobile Variant ID, from your register iOS Variant
        //
        // This ID was received when performing the HTTP-based registration
        // with the PushEE server:
        [clientInfo setMobileVariantID:@"55e465ce-cc52-4b77-a0ad-468420e3e985"];
        [clientInfo setMobileVariantSecret:@"a5d0232b-0cd1-4936-a908-1e76e11e5091"];
        
        
        // apply the token, to identify THIS device
        [clientInfo setDeviceToken:deviceToken];
        
        // alias is employee uid, we will use it to filter push broadcasts based on employee fields
        [clientInfo setAlias:kDefaultAppUserUID];
        
        // --optional config--
        // set some 'useful' hardware information params
        UIDevice *currentDevice = [UIDevice currentDevice];
        
        [clientInfo setOperatingSystem:[currentDevice systemName]];
        [clientInfo setOsVersion:[currentDevice systemVersion]];
        [clientInfo setDeviceType: [currentDevice model]];
        
    } success:^() {
        //
        NSLog(@"Device successfully registered to push server");
    } failure:^(NSError *error) {
        // did receive an HTTP error from the PushEE server ???
        // Let's log it for now:
        NSLog(@"PushEE registration Error: %@", error);
    }];
}

// There was an error with connecting to APNs or receiving an APNs generated token for this phone!
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    // something went wrong, while talking to APNs
    // Let's simply log it for now...:
    NSLog(@"APNs Error: %@", error);
}

// When the program is active, this callback receives the Payload of the Push Notification message
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    // A JSON object is received, represented as a NSDictionary.
    // use it to pick your custom key
    
    // For demo reasons, we simply read the "alert" key, from the "aps" dictionary:
    NSString *alertValue = [userInfo valueForKeyPath:@"aps.alert"];
    
    
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle: @"Custom Dialog, while Program is active"
                          message: alertValue
                          delegate: nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil];
    [alert show];
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
    
    // here if the badge icon is set, we know that a push message was arrived (as there is no delegate called if user simply ignores the notification, we can use this badge count as an indication of push message arrival)
//    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
//    
//    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
