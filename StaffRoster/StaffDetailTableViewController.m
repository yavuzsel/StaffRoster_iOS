//
//  StaffDetailTableViewController.m
//  StaffRoster
//
//  Created by yavuz on 5/23/13.
//  Copyright (c) 2013 redhat. All rights reserved.
//

#import "StaffDetailTableViewController.h"
#import "StaffRosterAPIClient.h"
#import "EmployeeSearchViewController.h"
#import "OfflineDataProvider.h"
#import <SDWebImage/UIImageView+WebCache.h>

#define PROFILE_PHOTO_TAG 1
#define PROFILE_NAME_TAG 2
#define PROFILE_TITLE_TAG 3
#define PROFILE_LOCATION_TAG 4
#define PROFILE_ROW_LABEL_TAG 5
#define ROW_PHOTO_TAG 6
#define ROW_TEXT_TAG 7
#define PROFILE_LOC_PIC_TAG 8

@interface StaffDetailTableViewController ()

@end

@implementation StaffDetailTableViewController {
    bool _load_mutex;
    NSInteger _num_of_dreports;
    NSInteger _num_of_colleagues;
    NSString *_profile_img_path;
}

@synthesize employee = _employee;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _load_mutex = true;
    _num_of_dreports = 0;
    _num_of_colleagues = 0;
    
    // put search button if only root view is employee search view
    // TODO: once profile is introduced, implpement a better way to set page title
    NSArray *viewControllers = self.navigationController.viewControllers;
    if (viewControllers.count > 0) {
        UIViewController *rootViewController = [viewControllers objectAtIndex:0];
        if ([rootViewController isKindOfClass:[EmployeeSearchViewController class]]) {
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(popToRoot:)];
            if (_employee) {
                self.navigationItem.title = [[NSString alloc] initWithFormat:@"%@'s Profile", ([[_employee objectForKey:@"cn"] length]<7)?[_employee objectForKey:@"cn"]:[[[_employee objectForKey:@"cn"] componentsSeparatedByString:@" "] objectAtIndex:0]];
            }
        } else {
            if ([viewControllers count] > 1) {
                if (_employee) {
                    self.navigationItem.title = [[NSString alloc] initWithFormat:@"%@'s Profile", ([[_employee objectForKey:@"cn"] length]<7)?[_employee objectForKey:@"cn"]:[[[_employee objectForKey:@"cn"] componentsSeparatedByString:@" "] objectAtIndex:0]];
                }
            } else {
                self.navigationItem.title = @"My Profile";
            }
        }
    }
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    UISwipeGestureRecognizer *fingerSwipeLeft = [[UISwipeGestureRecognizer alloc]
                                                     initWithTarget:self
                                                     action:@selector(fingerSwipeLeft:)];
    [fingerSwipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
    [[self view] addGestureRecognizer:fingerSwipeLeft];
    
    UISwipeGestureRecognizer *fingerSwipeRight = [[UISwipeGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(fingerSwipeRight:)];
    [fingerSwipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
    [[self view] addGestureRecognizer:fingerSwipeRight];
    
    
    UISwipeGestureRecognizer *fingerSwipeUp = [[UISwipeGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(fingerSwipeUp:)];
    [fingerSwipeUp setNumberOfTouchesRequired:2];
    [fingerSwipeUp setDirection:UISwipeGestureRecognizerDirectionRight]; // i know this is "right" although name says "up" :)
    [[self view] addGestureRecognizer:fingerSwipeUp];
    
    
    UISwipeGestureRecognizer *fingerSwipeDown = [[UISwipeGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(fingerSwipeDown:)];
    [fingerSwipeDown setNumberOfTouchesRequired:2];
    [fingerSwipeDown setDirection:UISwipeGestureRecognizerDirectionLeft]; // i know this is "left" although name says "down" :)
    [[self view] addGestureRecognizer:fingerSwipeDown];
    
    //self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor whiteColor];
    
    UIImageView *tempImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppBackground.png"]];
    //tempImageView.alpha = 0.1;
    [tempImageView setFrame:[[UIScreen mainScreen] bounds]];
    
    self.tableView.backgroundView = tempImageView;
    
    if (!_employee) {
        return;
    }

    // load number of direct reports, no need to hold lock
    [self loadNumberOfDReports];
    
    // load profile image path
    [self loadProfileImagePath];
}

- (void)loadProfileImagePath {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [[StaffRosterAPIClient sharedInstance].imageURLPipe readWithParams:@{@"uid": [_employee objectForKey:@"uid"]} success:^(id responseObject) {
        NSLog(@"Response image: %@", responseObject);
        _profile_img_path = [[responseObject objectAtIndex:0] objectForKey:@"img_url"];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[OfflineDataProvider sharedInstance] setProfileImagePath:_profile_img_path toEmployee:_employee];
        });
        [self respondToProfileImageLoad];
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
        // i need to ask to data provider, because if employee was loaded from LDAP, then it'd not have image url
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            _profile_img_path = [[OfflineDataProvider sharedInstance] getProfileImagePath:_employee];
            [self performSelectorOnMainThread:@selector(respondToProfileImageLoad) withObject:nil waitUntilDone:NO];
        });
    }];
}

- (void)respondToProfileImageLoad {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)loadNumberOfDReports {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [[StaffRosterAPIClient sharedInstance].dreportsPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"dreport": [_employee objectForKey:@"cn"], @"count":@"req"}] success:^(id responseObject) {
        NSLog(@"Response dreports count: %@", responseObject);
        _num_of_dreports = ([[responseObject objectAtIndex:0] objectForKey:@"count"] != [NSNull null])?[[[responseObject objectAtIndex:0] objectForKey:@"count"] integerValue]:0;
        [self respondToNumberOfDReportsLoad];
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            _num_of_dreports = [[OfflineDataProvider sharedInstance] getDReportsCount:[_employee objectForKey:@"cn"]];
            [self performSelectorOnMainThread:@selector(respondToNumberOfDReportsLoad) withObject:nil waitUntilDone:NO];
        });
    }];
}

- (void)respondToNumberOfDReportsLoad {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    if (_num_of_dreports == 0) {
        // !!!: this is here because async load causes problem when updating tableview
        [self loadNumberOfColleagues];
        return;
    }
    [self.tableView beginUpdates];
    if ([_employee objectForKey:@"telephonenumber"] != [NSNull null] && [[_employee objectForKey:@"telephonenumber"] length]) {
        [self.tableView insertSections:[NSIndexSet indexSetWithIndex:4] withRowAnimation:UITableViewRowAnimationFade];
    } else {
        [self.tableView insertSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
    }
    //[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView endUpdates];
    
    // !!!: this is here because async load causes problem when updating tableview
    [self loadNumberOfColleagues];
}

- (void)loadNumberOfColleagues {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [[StaffRosterAPIClient sharedInstance].colleaguesPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"colleague": [_employee objectForKey:@"cn"], @"count":@"req"}] success:^(id responseObject) {
        NSLog(@"Response colleagues count: %@", responseObject);
        _num_of_colleagues = ([[responseObject objectAtIndex:0] objectForKey:@"count"] != [NSNull null])?[[[responseObject objectAtIndex:0] objectForKey:@"count"] integerValue]:0;
        [self respondToNumberOfColleaguesLoad];
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            _num_of_colleagues = [[OfflineDataProvider sharedInstance] getColleaguesCount:[_employee objectForKey:@"cn"]];
            [self performSelectorOnMainThread:@selector(respondToNumberOfColleaguesLoad) withObject:nil waitUntilDone:NO];
        });
    }];
}

- (void)respondToNumberOfColleaguesLoad {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    if (_num_of_colleagues == 0) {
        return;
    }
    [self.tableView beginUpdates];
    if ([_employee objectForKey:@"telephonenumber"] != [NSNull null] && [[_employee objectForKey:@"telephonenumber"] length]) {
        if (_num_of_dreports > 0) {
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:5] withRowAnimation:UITableViewRowAnimationFade];
        } else {
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:4] withRowAnimation:UITableViewRowAnimationFade];
        }
    } else {
        if (_num_of_dreports > 0) {
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:4] withRowAnimation:UITableViewRowAnimationFade];
        } else {
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationFade];
        }
    }
    [self.tableView endUpdates];
}


- (IBAction)popToRoot:(id)sender {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)fingerSwipeLeft:(UITapGestureRecognizer *)recognizer {
    // Insert your own code to handle swipe left
    // this is needed only if i register same event for more than one gesture recognizer (i.e. for different number of touches required)
    NSUInteger touches = recognizer.numberOfTouches;
    switch (touches) {
        case 1:
            break;
        case 2:
            break;
        case 3:
            break;
        default:
            break;
    }
    [self loadDReports];
    NSLog(@"swiped left. %d touches.", touches);
}

- (void)fingerSwipeRight:(UITapGestureRecognizer *)recognizer {
    // Insert your own code to handle swipe right
    NSUInteger touches = recognizer.numberOfTouches;
    switch (touches) {
        case 1:
            break;
        case 2:
            break;
        case 3:
            break;
        default:
            break;
    }
    [self loadManager];
    NSLog(@"swiped right. %d touches.", touches);
}

- (void)fingerSwipeUp:(UITapGestureRecognizer *)recognizer {
    // Insert your own code to handle swipe up
    NSUInteger touches = recognizer.numberOfTouches;
    switch (touches) {
        case 1:
            break;
        case 2:
            break;
        case 3:
            break;
        default:
            break;
    }
    [self loadColleagues:kCATransitionFromLeft];
    NSLog(@"swiped up. %d touches.", touches);
}

- (void)fingerSwipeDown:(UITapGestureRecognizer *)recognizer {
    // Insert your own code to handle swipe down
    NSUInteger touches = recognizer.numberOfTouches;
    switch (touches) {
        case 1:
            break;
        case 2:
            break;
        case 3:
            break;
        default:
            break;
    }
    [self loadColleagues:kCATransitionFromRight];
    NSLog(@"swiped down. %d touches.", touches);
}

- (void)loadManager {
    if (!_load_mutex) {
        return;
    }
    _load_mutex = false;
    if (!_employee) {
        _load_mutex = true;
        return;
    }
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    // fetch the data
    [[StaffRosterAPIClient sharedInstance].managerPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"manager": [_employee objectForKey:@"cn"]}] success:^(id responseObject) {
        [self respondToManagerLoad:responseObject];
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            id manager = [[OfflineDataProvider sharedInstance] getManager:[_employee objectForKey:@"cn"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self respondToManagerLoad:manager];
            });
        });
    }];
}

- (void)respondToManagerLoad:(id)responseEmployee {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    NSLog(@"Response manager: %@", responseEmployee);
    // update table with the newly fetched data
    if ([responseEmployee count]) {
        CATransition* transition = [CATransition animation];
        transition.duration = 0.4f;
        transition.type = kCATransitionMoveIn;
        transition.subtype = kCATransitionFromBottom;
        [self.navigationController.view.layer addAnimation:transition
                                                    forKey:kCATransition];
        
        StaffDetailTableViewController *detailViewController = [[StaffDetailTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
        detailViewController.employee = [responseEmployee objectAtIndex:0];
        [self.navigationController pushViewController:detailViewController animated:NO];
        _load_mutex = true;
    } else {
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Oops!"
                                                          message:@"No manager found..."
                                                         delegate:nil
                                                cancelButtonTitle:@"OK"
                                                otherButtonTitles:nil];
        [message show];
        _load_mutex = true;
    }
}

- (void)loadColleagues:(NSString *)transitionSubtype {
    if (!_load_mutex) {
        return;
    }
    _load_mutex = false;
    if (!_employee) {
        _load_mutex = true;
        return;
    }
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    // fetch the data
    [[StaffRosterAPIClient sharedInstance].colleaguesPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"colleague": [_employee objectForKey:@"cn"]}] success:^(id responseObject) {
        [self respondToColleaguesLoad:responseObject withTransitionSubtype:transitionSubtype];
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSArray * colleagues = [[OfflineDataProvider sharedInstance] getColleagues:[_employee objectForKey:@"cn"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self respondToColleaguesLoad:colleagues withTransitionSubtype:transitionSubtype];
            });
        });
    }];
}

- (void)respondToColleaguesLoad:(id)responseObject withTransitionSubtype:(NSString *)subtype {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    NSLog(@"Response colleagues: %@", responseObject);
    if ([responseObject count]) {
        CATransition* transition = [CATransition animation];
        transition.duration = 0.4f;
        transition.type = kCATransitionReveal;
        transition.subtype = subtype;
        [self.navigationController.view.layer addAnimation:transition
                                                    forKey:kCATransition];
        EmployeeSearchViewController *detailViewController = [[EmployeeSearchViewController alloc] initWithStyle:UITableViewStyleGrouped];
        detailViewController.employees = responseObject;
        detailViewController.titleName = [_employee objectForKey:@"cn"];
        detailViewController.pageType = kEmployeeSearchViewPageTypeColleagues;
        [self.navigationController pushViewController:detailViewController animated:NO];
        _load_mutex = true;
    } else {
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Oops!"
                                                          message:@"No peers found..."
                                                         delegate:nil
                                                cancelButtonTitle:@"OK"
                                                otherButtonTitles:nil];
        [message show];
        _load_mutex = true;
    }
}

- (void)loadDReports {
    [self loadDReports:kCATransitionFromTop];
}

- (void)loadDReports:(NSString *)transitionSubtype {
    if (!_load_mutex) {
        return;
    }
    _load_mutex = false;
    if (!_employee) {
        _load_mutex = true;
        return;
    }
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    // fetch the data
    [[StaffRosterAPIClient sharedInstance].dreportsPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"dreport": [_employee objectForKey:@"cn"]}] success:^(id responseObject) {
        [self respondToDReportsLoad:responseObject withTransitionSubtype:transitionSubtype];
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSArray * dReports = [[OfflineDataProvider sharedInstance] getDReports:[_employee objectForKey:@"cn"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self respondToDReportsLoad:dReports withTransitionSubtype:transitionSubtype];
            });
        });
    }];
}

- (void)respondToDReportsLoad:(id)responseObject withTransitionSubtype:(NSString *)transitionSubtype {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    NSLog(@"Response dreports: %@", responseObject);
    CATransition* transition = [CATransition animation];
    transition.duration = 0.4f;
    transition.type = kCATransitionMoveIn;
    transition.subtype = transitionSubtype;
    [self.navigationController.view.layer addAnimation:transition
                                                forKey:kCATransition];
    EmployeeSearchViewController *detailViewController = [[EmployeeSearchViewController alloc] initWithStyle:UITableViewStyleGrouped];
    detailViewController.employees = responseObject;
    detailViewController.titleName = [_employee objectForKey:@"cn"];
    detailViewController.pageType = kEmployeeSearchViewPageTypeDReports;
    /*[UIView animateWithDuration:0.75
     animations:^{
     [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
     [self.navigationController pushViewController:detailViewController animated:NO];
     [UIView setAnimationTransition:UIViewAnimationTransitionCurlUp forView:self.navigationController.view cache:NO];
     }];*/
    [self.navigationController pushViewController:detailViewController animated:NO];
    _load_mutex = true;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (!_employee) {
        return 0;
    }
    // Return the number of sections.
    return (([_employee objectForKey:@"telephonenumber"] != [NSNull null] && [[_employee objectForKey:@"telephonenumber"] length])?4:3)+((_num_of_dreports>0)?1:0)+((_num_of_colleagues>0)?1:0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return 1;
}

// UX decision: no footers!
//- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
//    if (section == 0 && _num_of_dreports > 0) {
//        return [[NSString alloc] initWithFormat:@"%d direct reports", _num_of_dreports];
//    }
//    return nil;
//}

// UX decision: no headers!
//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
//    switch (section) {
////        case 0:
////            return @"Name:";
////            break;
//            
//        case 1:
//            return ([_employee objectForKey:@"title"] != [NSNull null] && [[_employee objectForKey:@"title"] length])?@"Title:":@"Location:";
//            break;
//            
//        case 2:
//            return ([_employee objectForKey:@"title"] != [NSNull null] && [[_employee objectForKey:@"title"] length])?@"Location:":@"e-Mail:";
//            break;
//            
////        case 3:
////            return ([_employee objectForKey:@"title"] != [NSNull null] && [[_employee objectForKey:@"title"] length])?@"e-Mail:":@"Phone:";
////            break;
////            
////        case 4:
////            return @"Phone:";
////            break;
//            
//        default:
//            return @"";
//            break;
//    }
//}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return 0.9f;
    }
    if ([_employee objectForKey:@"telephonenumber"] != [NSNull null] && [[_employee objectForKey:@"telephonenumber"] length]) {
        if (section == 2) {
            return 2.0f;
        }
        if (_num_of_colleagues > 0 && _num_of_dreports > 0 && section == 4) {
            return 2.0f;
        }
    } else {
        if (_num_of_colleagues > 0 && _num_of_dreports > 0 && section == 3) {
            return 2.0f;
        }
    }
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return 0.1f;
    }
    if ([_employee objectForKey:@"telephonenumber"] != [NSNull null] && [[_employee objectForKey:@"telephonenumber"] length]) {
        if (section == 3) {
            return 2.0f;
        }
        if (_num_of_colleagues > 0 && _num_of_dreports > 0 && section == 5) {
            return 2.0f;
        }
    } else {
        if (_num_of_colleagues > 0 && _num_of_dreports > 0 && section == 4) {
            return 2.0f;
        }
    }
    return UITableViewAutomaticDimension;
}

- (void)viewWillAppear:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat widthDiff = 18.0f; // don't like hardcoding this. find a way to calculate!
    CGFloat locAdjust = 10.0f;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        widthDiff = 88.0f; // grouped tableview ipad cell width = (screen width - 88)
        locAdjust = -10.0f;
    }
    if (_employee && indexPath.section == 0) {
        static NSString *PNameCellIdentifier = @"PNameCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:PNameCellIdentifier];
        UIImageView *prflPhoto;
        UILabel *cnLabel;
        UILabel *titleLabel;
        if (cell == nil) {
            cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PNameCellIdentifier];
            cell.frame = CGRectMake(0.0f, 0.0f, [[UIScreen mainScreen] bounds].size.width, 200.0f);
            prflPhoto = [[UIImageView alloc] initWithFrame:CGRectMake(([[UIScreen mainScreen] bounds].size.width-149.5f-widthDiff)/2.0f, 12.0f, 149.5f, 112.0f)];
            prflPhoto.tag = PROFILE_PHOTO_TAG;
            prflPhoto.layer.cornerRadius = 5.0f;
            prflPhoto.clipsToBounds = YES;
            prflPhoto.layer.borderWidth = 3.0f;
            prflPhoto.layer.borderColor = [UIColor colorWithRed:100.0f/255.0f green:100.0f/255.0f blue:100.0f/255.0f alpha:1.0f].CGColor;
            [cell.contentView addSubview:prflPhoto];
            
            cnLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.5f, 136.0f, [[UIScreen mainScreen] bounds].size.width - widthDiff, 32.0f)];
            cnLabel.backgroundColor = [UIColor clearColor];
            cnLabel.tag = PROFILE_NAME_TAG;
            cnLabel.font = [UIFont boldSystemFontOfSize:21.0f];
            cnLabel.textAlignment = UITextAlignmentCenter;
            cnLabel.numberOfLines = 0;
            [cell.contentView addSubview:cnLabel];
            
            titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.5f, 168.0f, [[UIScreen mainScreen] bounds].size.width - widthDiff, 32.0f)];
            titleLabel.backgroundColor = [UIColor clearColor];
            titleLabel.tag = PROFILE_TITLE_TAG;
            titleLabel.font = [UIFont systemFontOfSize:13.0f];
            titleLabel.textAlignment = UITextAlignmentCenter;
            titleLabel.numberOfLines = 0;
            [cell.contentView addSubview:titleLabel];

            cell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            prflPhoto = (UIImageView *)[cell.contentView viewWithTag:PROFILE_PHOTO_TAG];
            cnLabel = (UILabel *)[cell.contentView viewWithTag:PROFILE_NAME_TAG];
            titleLabel = (UILabel *)[cell.contentView viewWithTag:PROFILE_TITLE_TAG];
        }
        cnLabel.text = [_employee objectForKey:@"cn"];
        [prflPhoto setImageWithURL:[NSURL URLWithString:_profile_img_path] placeholderImage:[UIImage imageNamed:@"StaffAppIcon_HiRes.png"]];
        if([_employee objectForKey:@"title"] != [NSNull null] && [[_employee objectForKey:@"title"] length]) {
            titleLabel.text = [_employee objectForKey:@"title"];
        } else {
            titleLabel.hidden = YES;
        }
        return cell;
    }
    
    if (_employee && indexPath.section == 1) {
        static NSString *PLocationCellIdentifier = @"PLocationCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:PLocationCellIdentifier];
        UIImageView *locPhoto;
        UILabel *locationLabel;
        if (cell == nil) {
            cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PLocationCellIdentifier];
            cell.frame = CGRectMake(0.0f, 0.0f, [[UIScreen mainScreen] bounds].size.width, 24.0f);
            locPhoto = [[UIImageView alloc] initWithFrame:CGRectMake(([[UIScreen mainScreen] bounds].size.width/4.0f)-(widthDiff/2.0f), 0.0f, 24.0f, 24.0f)];
            locPhoto.tag = PROFILE_LOC_PIC_TAG;
            locPhoto.layer.cornerRadius = 5.0f;
            locPhoto.clipsToBounds = YES;
            [cell.contentView addSubview:locPhoto];
            
            locationLabel = [[UILabel alloc] initWithFrame:CGRectMake(12.0f, 0.0f, [[UIScreen mainScreen] bounds].size.width - widthDiff, 24.0f)];
            locationLabel.backgroundColor = [UIColor clearColor];
            locationLabel.tag = PROFILE_LOCATION_TAG;
            locationLabel.font = [UIFont systemFontOfSize:13.0f];
            locationLabel.textAlignment = UITextAlignmentCenter;
            locationLabel.numberOfLines = 0;
            [cell.contentView addSubview:locationLabel];
            
            cell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
        } else {
            locPhoto = (UIImageView *)[cell.contentView viewWithTag:PROFILE_LOC_PIC_TAG];
            locationLabel = (UILabel *)[cell.contentView viewWithTag:PROFILE_LOCATION_TAG];
        }
        CGSize sizeOfText = [[_employee objectForKey:@"rhatlocation"] sizeWithFont:locationLabel.font constrainedToSize:CGSizeMake([[UIScreen mainScreen] bounds].size.width - widthDiff, 24.0f) lineBreakMode:locationLabel.lineBreakMode];
        CGRect photoFrame = locPhoto.frame;
        photoFrame.origin.x = ([[UIScreen mainScreen] bounds].size.width/2.0f)-(sizeOfText.width/2.0f)-widthDiff-locAdjust;
        locPhoto.frame = photoFrame;
        [locPhoto setImage:[UIImage imageNamed:@"icon_office.png"]];
        locationLabel.text = [_employee objectForKey:@"rhatlocation"];
        
        return cell;
    }
    
    if (_employee && (indexPath.section == 2 || (([_employee objectForKey:@"telephonenumber"] != [NSNull null] && [[_employee objectForKey:@"telephonenumber"] length]) && indexPath.section == 3))) {
        static NSString *PPhotoRowCellIdentifier = @"PPhotoRowCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:PPhotoRowCellIdentifier];
        UIImageView *rowPhoto;
        UITextView *clickableLabel;
        if (cell == nil) {
            cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PPhotoRowCellIdentifier];
            cell.frame = CGRectMake(0.0f, 0.0f, [[UIScreen mainScreen] bounds].size.width, 46.0f);
            rowPhoto = [[UIImageView alloc] initWithFrame:CGRectMake(10.0f, 5.0f, 36.0f, 36.0f)];
            rowPhoto.tag = ROW_PHOTO_TAG;
            rowPhoto.layer.cornerRadius = 2.0f;
            rowPhoto.clipsToBounds = YES;
            [cell.contentView addSubview:rowPhoto];
            
            UIView *seperator = [[UIView alloc] initWithFrame:CGRectMake(56.0f, 0.0f, 1.0f, 45.0f)];
            [seperator setBackgroundColor:[UIColor lightGrayColor]];
            [cell.contentView addSubview:seperator];
            
            clickableLabel = [[UITextView alloc] initWithFrame:CGRectMake(67.0f, 5.0f, [[UIScreen mainScreen] bounds].size.width - 77 - widthDiff, 36.0f)];
            clickableLabel.backgroundColor = [UIColor groupTableViewBackgroundColor];
            clickableLabel.tag = ROW_TEXT_TAG;
            clickableLabel.font = [UIFont boldSystemFontOfSize:17.0f];
            clickableLabel.textAlignment = NSTextAlignmentNatural;
            clickableLabel.editable = NO;
            clickableLabel.scrollEnabled = NO;
            clickableLabel.dataDetectorTypes = UIDataDetectorTypeAll;
            [cell.contentView addSubview:clickableLabel];
            cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pipe.png"]];
            cell.backgroundView.layer.cornerRadius = 10.0f;
            cell.backgroundView.clipsToBounds = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.backgroundView.layer.borderWidth = 1.0f;
            cell.backgroundView.layer.borderColor = [UIColor lightGrayColor].CGColor;
        } else {
            rowPhoto = (UIImageView *)[cell.contentView viewWithTag:ROW_PHOTO_TAG];
            clickableLabel = (UITextView *)[cell.contentView viewWithTag:ROW_TEXT_TAG];
        }
        if (indexPath.section == 2) {
            clickableLabel.text = [_employee objectForKey:@"mail"];
            [rowPhoto setImage:[UIImage imageNamed:@"icon_email.png"]];
        } else if (([_employee objectForKey:@"telephonenumber"] != [NSNull null] && [[_employee objectForKey:@"telephonenumber"] length]) && indexPath.section == 3) {
            clickableLabel.text = [self formatPhoneNumber:[_employee objectForKey:@"telephonenumber"]];
            [rowPhoto setImage:[UIImage imageNamed:@"icon_phone.png"]];
        }
        
        // as the row is selectable, adjust the size of the textview
        CGSize adjSize = [clickableLabel.text sizeWithFont:clickableLabel.font];
        CGRect rect = clickableLabel.frame;
        rect.size.width = adjSize.width + 16; // uitextview needs some more space to fit, need to find a better way :S
        clickableLabel.frame = rect;
        
        return cell;
    }
    
    static NSString *PInfoCellIdentifier = @"PInfoCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:PInfoCellIdentifier];
    UILabel *mainLabel;
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PInfoCellIdentifier];
        mainLabel = [[UILabel alloc] initWithFrame:CGRectMake(25.0f, 4.0f, [[UIScreen mainScreen] bounds].size.width-50-widthDiff, 36.0f)];
        mainLabel.backgroundColor = [UIColor groupTableViewBackgroundColor];
        mainLabel.tag = PROFILE_ROW_LABEL_TAG;
        mainLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        mainLabel.textAlignment = NSTextAlignmentLeft;
        [cell.contentView addSubview:mainLabel];
        cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pipe.png"]];
        cell.backgroundView.layer.cornerRadius = 10.0f;
        cell.backgroundView.clipsToBounds = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundView.layer.borderWidth = 1.0f;
        cell.backgroundView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    } else {
        mainLabel = (UILabel *)[cell.contentView viewWithTag:PROFILE_ROW_LABEL_TAG];
    }
    
    // this should not happen at all!
    if (!_employee) {
        mainLabel.text = @"ERROR";
        return cell;
    }
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    switch (indexPath.section) {
        case 3: {
            if (_num_of_dreports > 0) {
                mainLabel.text =  [[NSString alloc] initWithFormat:@"%d direct report%@", _num_of_dreports, ((_num_of_dreports==1)?@"":@"s")];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else if (_num_of_colleagues > 0) {
                mainLabel.text =  [[NSString alloc] initWithFormat:@"%d peer%@", _num_of_colleagues, ((_num_of_colleagues==1)?@"":@"s")];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            break;
        }
            
        case 4: {
            if ([_employee objectForKey:@"telephonenumber"] != [NSNull null] && [[_employee objectForKey:@"telephonenumber"] length]) {
                if (_num_of_dreports > 0) {
                    mainLabel.text =  [[NSString alloc] initWithFormat:@"%d direct report%@", _num_of_dreports, ((_num_of_dreports==1)?@"":@"s")];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                } else if (_num_of_colleagues > 0) {
                    mainLabel.text =  [[NSString alloc] initWithFormat:@"%d peer%@", _num_of_colleagues, ((_num_of_colleagues==1)?@"":@"s")];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                }
            } else {
                mainLabel.text =  [[NSString alloc] initWithFormat:@"%d peer%@", _num_of_colleagues, ((_num_of_colleagues==1)?@"":@"s")];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            break;
        }

        case 5:
            mainLabel.text =  [[NSString alloc] initWithFormat:@"%d peer%@", _num_of_colleagues, ((_num_of_colleagues==1)?@"":@"s")];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
            
        default:
            break;
    }
    return cell;
}


/* 
 * following code snippet to format phone number is taken from http://code.shabz.co/post/29634499026/format-a-phone-number
 * it is modified for ARC
 */
- (NSString *)formatPhoneNumber:(NSString *)phoneNumber {
    NSArray *usFormats = [NSArray arrayWithObjects:@"+1 (###) ###-####", @"1 (###) ###-####", @"011 $", @"###-####", @"(###) ###-####", nil];
    if(usFormats == nil) {
        return phoneNumber;
    }
    NSString *output = [self strip:phoneNumber];
    for(NSString *phoneFormat in usFormats) {
        int i = 0;
        NSMutableString *temp = [[NSMutableString alloc] init];
        for(int p = 0; temp != nil && i < [output length] && p < [phoneFormat length]; p++) {
            char c = [phoneFormat characterAtIndex:p];
            BOOL required = [self canBeInputByPhonePad:c];
            char next = [output characterAtIndex:i];
            switch(c) {
                case '$':
                    p--;
                    [temp appendFormat:@"%c", next];
                    i++;
                    break;
                    
                case '#':
                    if(next < '0' || next > '9') {
                        temp = nil;
                        break;
                    }
                    [temp appendFormat:@"%c", next];
                    i++;
                    break;
                    
                default:
                    if(required) {
                        if(next != c) {
                            temp = nil;
                            break;
                        }
                        [temp appendFormat:@"%c", next];
                        i++;
                    } else {
                        [temp appendFormat:@"%c", c];
                        if(next == c) {
                            i++;
                        }
                    }
                    break;
            }
        }
        if(i == [output length]) {
            return temp;
        }
    }
    return output;
}

- (NSString *)strip:(NSString *)phoneNumber {
    NSMutableString *res = [[NSMutableString alloc] init];
    for(int i = 0; i < [phoneNumber length]; i++) {
        char next = [phoneNumber characterAtIndex:i];
        if([self canBeInputByPhonePad:next])
            [res appendFormat:@"%c", next];
    }
    return res;
}

- (BOOL)canBeInputByPhonePad:(char)c {
    if(c == '+' || c == '*' || c == '#') {
        return YES;
    }
    if(c >= '0' && c <= '9') {
        return YES;
    }
    return NO;
}
/*
 * end of phone formatting code snippet
 */


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 200.0f;
    } else if (indexPath.section == 1) {
        return 24.0f;
    }
    return UITableViewAutomaticDimension;
    //    } else if (indexPath.section == 4 || indexPath.section == 3) { // there is a better way of doing this. just find what your tag is gonna be, instead of repeating the code!!!
    //        UITableViewCell *cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
    //        return ((UITextView *)[cell.contentView viewWithTag:ROW_TEXT_TAG]).contentSize.height+9;
    //    } else {
    //        UITableViewCell *cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
    //        // why adding 9? the contentSize.height for a single line label is 37, and the standard cell height is 46 (for a 96grouped tableview).
    //        // !!!: find a way to calculate height automatically.
    //        return ((UITextView *)[cell.contentView viewWithTag:PROFILE_CLICKABLE_TAG]).contentSize.height+9;
    //    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 5) {
        [self loadColleagues:kCATransitionFromRight];
    } else if (indexPath.section == 4) {
        if (_num_of_dreports == 0) {
            [self loadColleagues:kCATransitionFromRight];
        } else {
            if ([_employee objectForKey:@"telephonenumber"] != [NSNull null] && [[_employee objectForKey:@"telephonenumber"] length]) {
                [self loadDReports:kCATransitionFromRight];
            } else {
                [self loadColleagues:kCATransitionFromRight];
            }
        }
    } else if (indexPath.section == 3) {
        if (!([_employee objectForKey:@"telephonenumber"] != [NSNull null] && [[_employee objectForKey:@"telephonenumber"] length])) {
            if (_num_of_dreports > 0) {
                [self loadDReports:kCATransitionFromRight];
            } else {
                [self loadColleagues:kCATransitionFromRight];
            }
        } else {
            [self dialPhoneNumber:[_employee objectForKey:@"telephonenumber"]];
        }
    } else if (indexPath.section == 2) {
        [self sendMailTo:[_employee objectForKey:@"mail"]];
    }
}

- (void)sendMailTo:(NSString *)eMailAddress {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[[NSString alloc] initWithFormat:@"mailto:%@", eMailAddress]]];
}

- (void)dialPhoneNumber:(NSString *)phoneNumber {
    NSURL *phoneURL = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@",phoneNumber]];
    UIWebView *phoneCallWebView = [[UIWebView alloc] initWithFrame:CGRectZero];
    [phoneCallWebView loadRequest:[NSURLRequest requestWithURL:phoneURL]];
}

@end
