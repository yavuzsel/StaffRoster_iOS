//  ViewController.h
//
//  Generated by the the JBoss AeroGear Xcode Project Template on 5/23/13.
//  See Project's web site for more details http://www.aerogear.org
//

#import <UIKit/UIKit.h>

@interface EmployeeSearchViewController : UITableViewController <UISearchBarDelegate>

typedef enum {
    kEmployeeSearchViewPageTypeSearch,
    kEmployeeSearchViewPageTypeColleagues,
    kEmployeeSearchViewPageTypeDReports
} EmployeeSearchViewPageType;

@property EmployeeSearchViewPageType pageType;
@property NSArray *employees;
@property NSString *titleName;
@property bool pageSubtypeSortTypeIsLocation;

@end