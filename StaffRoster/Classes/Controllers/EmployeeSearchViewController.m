//  ViewController.m
//
//  Generated by the the JBoss AeroGear Xcode Project Template on 5/23/13.
//  See Project's web site for more details http://www.aerogear.org
//

#import "EmployeeSearchViewController.h"
#import "StaffRosterAPIClient.h"
#import "StaffDetailTableViewController.h"
#import "OfflineDataProvider.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import "EmployeeListCell.h"
#import "RHLocation.h"

#define ATOZ_TAG 1
#define LOC_TAG 2

@implementation EmployeeSearchViewController {
    UISearchBar *_searchBar;
    bool _load_mutex;
    bool _is_search_cancelled;
    NSMutableArray *locBasedSortResult;
    UITapGestureRecognizer *tapGesture;
}

@synthesize employees = _employees;
@synthesize pageType = _pageType;
@synthesize titleName = _titleName;
@synthesize pageSubtypeSortTypeIsLocation = _pageSubtypeSortTypeIsLocation;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (!_pageType) {
        // default to search page
        _pageType = kEmployeeSearchViewPageTypeSearch;
    }
    
    if (_pageType == kEmployeeSearchViewPageTypeSearch) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(popToRoot:)];
    } else {
        NSArray *viewControllers = self.navigationController.viewControllers;
        if (viewControllers.count > 0) {
            UIViewController *rootViewController = [viewControllers objectAtIndex:0];
            if ([rootViewController isKindOfClass:[EmployeeSearchViewController class]]) {
                self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(popToRoot:)];
            }
        }
    }
    
    _pageSubtypeSortTypeIsLocation = false;
    
    //self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor whiteColor];
    
    UIImageView *tempImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppBackground.png"]];
    //tempImageView.alpha = 0.1;
    [tempImageView setFrame:[[UIScreen mainScreen] bounds]];
    
    self.tableView.backgroundView = tempImageView;
    
    // set title according to page type and corresponding employee name (_titleName)
    NSString *titleText;
    switch (_pageType) {
        case kEmployeeSearchViewPageTypeSearch:
            // no visible title bar but it modifies back button text, so have it here
            titleText = @"Search";
            break;
            
        case kEmployeeSearchViewPageTypeColleagues:
            titleText = [[NSString alloc] initWithFormat:@"%@'s Peer%@", ([_titleName length]<7)?_titleName:[[_titleName componentsSeparatedByString:@" "] objectAtIndex:0], (([_employees count]==1)?@"":@"s")];
            break;
            
        case kEmployeeSearchViewPageTypeDReports:
            titleText = [[NSString alloc] initWithFormat:@"%@'s Report%@", ([_titleName length]<7)?_titleName:[[_titleName componentsSeparatedByString:@" "] objectAtIndex:0], (([_employees count]==1)?@"":@"s")];
            break;
            
        default:
            break;
    }
    self.navigationItem.title = titleText;
    
    _load_mutex = true;
    
    if (_pageType != kEmployeeSearchViewPageTypeSearch) {
        // sort employees by name
        NSSortDescriptor *valueDescriptor = [[NSSortDescriptor alloc] initWithKey:@"cn" ascending:YES];
        NSArray * descriptors = [NSArray arrayWithObject:valueDescriptor];
        _employees = [[_employees sortedArrayUsingDescriptors:descriptors] mutableCopy];
        
        self.tableView.rowHeight = 64.0f;
        return;
    }
    self.tableView.rowHeight = 44.0f;
    
    tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
    
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0, 0.0, [[UIScreen mainScreen] bounds].size.width, self.tableView.rowHeight)];
    _searchBar.delegate = self;
    _searchBar.tintColor = kAppTintColor;
    _searchBar.placeholder = @"type first name";
	self.tableView.tableHeaderView = _searchBar;
    
    _is_search_cancelled = false;
}

- (void)viewWillAppear:(BOOL)animated {
    if (_pageType != kEmployeeSearchViewPageTypeSearch) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    } else {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    }
}

- (IBAction)popToRoot:(id)sender {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

// hide keyboard when scrolling on the tableview begins
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [_searchBar resignFirstResponder];
    _searchBar.showsCancelButton = NO;
    [self.tableView removeGestureRecognizer:tapGesture];
}

// tap gesture is resigning the keyboard when search results are not there
- (void)handleTapFrom:(id)sender {
    [self.tableView removeGestureRecognizer:tapGesture];
    [_searchBar resignFirstResponder];
    _searchBar.showsCancelButton = NO;
}

#pragma mark - UISearchBar delegate methods

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    searchBar.showsCancelButton = YES;
    if (![_employees count]) {
        [self.tableView addGestureRecognizer:tapGesture];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([searchText length] < 3) {
        _is_search_cancelled = true;
        [[StaffRosterAPIClient sharedInstance].employeesPipe cancel];
        @synchronized(self){
            _employees = nil;
        }
        [self.tableView reloadData];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        [self.tableView addGestureRecognizer:tapGesture];        
        return;
    }
    _is_search_cancelled = false;
    if (!_load_mutex) {
        return;
    }
    _load_mutex = false;
    [self.tableView removeGestureRecognizer:tapGesture];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    // cancel previous queries
    [[StaffRosterAPIClient sharedInstance].employeesPipe cancel];
    // fetch the new data
    [[StaffRosterAPIClient sharedInstance].employeesPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"query": searchText}] success:^(id responseObject) {
        
        // sorting takes time, so do 
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSLog(@"Response obj: %@", responseObject);
            if (_is_search_cancelled) {
                return;
            }
            @synchronized(self){
                _employees = responseObject;
                if (!_employees.count) {
                    [self.tableView addGestureRecognizer:tapGesture];
                } else {
                    // sort employees by name
                    NSSortDescriptor *valueDescriptor = [[NSSortDescriptor alloc] initWithKey:@"cn" ascending:YES];
                    NSArray * descriptors = [NSArray arrayWithObject:valueDescriptor];
                    _employees = [[_employees sortedArrayUsingDescriptors:descriptors] mutableCopy];
                }
            }
            [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        });
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
        // reading from offlinedataprovider takes time on some devices, do async
        // TODO: make sure that sequential read request responses will be executed in the same order
        // when it is put in the same priority queue, it starts executing sequentially, but on multicore devices, execution time and presenting the results vary
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // !!!: the execution of the thread (even if i set priority appropriately) has some delay causes empty list to be filled again.
            // in order to avoid, i am using a flag here. search cancelled means there should not be any employee in the list. (searchText.length < 3)
            if (_is_search_cancelled) {
                return;
            }
            // !!!: sequential execution cancels loading indicator on slow networks
            // todo fix above should fix this issue too
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            @synchronized(self){
                // read synchronized to make sure each search request evaluates sequentially (adresses to the "todo" above)
                _employees = [[[OfflineDataProvider sharedInstance] getEmployees:searchText] mutableCopy];
                
                if (!_employees.count) {
                    [self.tableView addGestureRecognizer:tapGesture];
                } else {
                    // sort employees by name
                    NSSortDescriptor *valueDescriptor = [[NSSortDescriptor alloc] initWithKey:@"cn" ascending:YES];
                    NSArray * descriptors = [NSArray arrayWithObject:valueDescriptor];
                    _employees = [[_employees sortedArrayUsingDescriptors:descriptors] mutableCopy];
                }
            }
            [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        });
    }];
    _load_mutex = true;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    searchBar.showsCancelButton = NO;
    [self.tableView removeGestureRecognizer:tapGesture];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_pageType == kEmployeeSearchViewPageTypeSearch) {
        return 1;
    }
    if (_pageSubtypeSortTypeIsLocation) {
        return locBasedSortResult.count+1;
    }
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_pageSubtypeSortTypeIsLocation && section > 0) {
        return ((RHLocation *)[locBasedSortResult objectAtIndex:(section-1)]).employeeList.count;
    }
    if (_pageType == kEmployeeSearchViewPageTypeSearch || section > 0) {
        return ([_employees count])?([_employees count]):1;
    }
    return 1;
}

// <!-- leaving this for more efficient solution -->
// cell height problem trials (round top and bottom corners and draw cell borders with a custom background), here is another solution.
/*
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat widthDiff = 18.0f; // don't like hardcoding this. find a way to calculate!
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        widthDiff = 88.0f; // grouped tableview ipad cell width = (screen width - 88)
    }
    //NSLog(@"Cell Bounds: %@", NSStringFromCGRect(cell.bounds));
    CGRect origFrame = cell.bounds;
    origFrame.size.width = cell.bounds.size.width - widthDiff;
    origFrame.size.height = cell.bounds.size.height + 1; // !!!: don't know why this +1 fixes. my border width (layers line width below)?
    
    // set background image
    UIImageView *bgImg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pipe.png"]];
    [bgImg setFrame:origFrame];
    cell.backgroundView = bgImg;

    // round top corners of cell 0 and bottom corners of cell N
    UIBezierPath *maskPath;
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = origFrame;
    UIRectCorner corner = UIRectCornerAllCorners;
    //NSLog(@"Cell BG Bounds: %@", NSStringFromCGRect(origFrame));
    
    if ([_employees count] > 1 && indexPath.row != 0 && indexPath.row != [_employees count]-1) {
        maskPath = [UIBezierPath bezierPathWithRect:origFrame];
    } else {
        if ([_employees count] > 1) {
            if (indexPath.row == 0) {
                corner = (UIRectCornerTopLeft| UIRectCornerTopRight);
            } else if (indexPath.row == [_employees count]-1) {
                corner = (UIRectCornerBottomLeft| UIRectCornerBottomRight);
            }
        }
        maskPath = [UIBezierPath bezierPathWithRoundedRect:origFrame byRoundingCorners:corner cornerRadii:CGSizeMake(10.0, 10.0)];
    }
    maskLayer.path = maskPath.CGPath;
    cell.backgroundView.layer.mask = maskLayer;

    // draw border
    CAShapeLayer *strokeLayer = [CAShapeLayer layer];
    strokeLayer.path = maskPath.CGPath;
    strokeLayer.fillColor = [UIColor clearColor].CGColor;
    strokeLayer.strokeColor = [UIColor lightGrayColor].CGColor;
    strokeLayer.lineWidth = 4;
    UIView *strokeView = [[UIView alloc] initWithFrame:origFrame];
    strokeView.userInteractionEnabled = NO;
    [strokeView.layer addSublayer:strokeLayer];
    [cell.backgroundView addSubview:strokeView];
}
*/

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // when cell content view is customized, these needs to be set here
    // but it is more costly that setting them on create
    // so search cells are not customized and not set here
    if (_pageType != kEmployeeSearchViewPageTypeSearch && indexPath.section > 0) {
        cell.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"pipe_long.png"]];
        cell.detailTextLabel.backgroundColor = [UIColor clearColor];
        cell.textLabel.backgroundColor = [UIColor clearColor];
    }
}

- (void)sortByLocation {
    if (locBasedSortResult) {
        return;
    }
    locBasedSortResult = [[NSMutableArray alloc] init];
    bool isLocExist;
    for (id employee in _employees) {
        isLocExist = false;
        for (id rhLocation in locBasedSortResult) {
            if ([((RHLocation *)rhLocation).locName isEqual:[employee objectForKey:@"rhatlocation"]]) {
                [((RHLocation *)rhLocation).employeeList addObject:employee];
                isLocExist = true;
                break;
            }
        }
        if (!isLocExist) {
            RHLocation *newLocation = [[RHLocation alloc] init];
            newLocation.locName = [employee objectForKey:@"rhatlocation"];
            [newLocation.employeeList addObject:employee];
            [locBasedSortResult addObject:newLocation];
        }
    }
    // sort by location
    NSSortDescriptor *valueDescriptor = [[NSSortDescriptor alloc] initWithKey:@"locName" ascending:YES];
    NSArray * descriptors = [NSArray arrayWithObject:valueDescriptor];
    locBasedSortResult = [[locBasedSortResult sortedArrayUsingDescriptors:descriptors] mutableCopy];
}

- (void)sortClicked:(id)sender {
    UIButton *clickedBtn = (UIButton *)sender;
    if (clickedBtn.tag == LOC_TAG) {
        if (_pageSubtypeSortTypeIsLocation) {
            return;
        } else if (!_pageSubtypeSortTypeIsLocation) {
            clickedBtn.backgroundColor = [UIColor lightGrayColor];
            UIButton *atozBtn = (UIButton *)[clickedBtn.superview viewWithTag:ATOZ_TAG];
            atozBtn.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"pipe.png"]];
            _pageSubtypeSortTypeIsLocation = true;
            [self sortByLocation];
            [self.tableView reloadData];
        }
    } else if (clickedBtn.tag == ATOZ_TAG) {
        if (_pageSubtypeSortTypeIsLocation) {
            clickedBtn.backgroundColor = [UIColor lightGrayColor];
            UIButton *locBtn = (UIButton *)[clickedBtn.superview viewWithTag:LOC_TAG];
            locBtn.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"pipe.png"]];
            _pageSubtypeSortTypeIsLocation = false;
            // !!!: find a good animation for sorting the list
            [self.tableView reloadData];
        } else if (!_pageSubtypeSortTypeIsLocation) {
            return;
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier;// = @"Cell";
    
    if (indexPath.section == 0 && _pageType != kEmployeeSearchViewPageTypeSearch) {
        CellIdentifier = @"SortSectionCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            cell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
            cell.backgroundColor = [UIColor clearColor];
            // create sort buttons section here
            UIView *sortSection = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, [[UIScreen mainScreen] bounds].size.width, 118.0f)];
            UILabel *pageTitle = [[UILabel alloc] initWithFrame:CGRectMake(15.0f, 5.0f, [[UIScreen mainScreen] bounds].size.width-30.0f, 44.0f)];
            pageTitle.backgroundColor = [UIColor clearColor];
            pageTitle.font = [UIFont boldSystemFontOfSize:17.0f];
            if ([_employees count]) {
                if (_pageType == kEmployeeSearchViewPageTypeDReports) {
                    pageTitle.text = [[NSString alloc] initWithFormat:@"%@'s Direct Report%@:", ([_titleName length]<7)?_titleName:[[_titleName componentsSeparatedByString:@" "] objectAtIndex:0], (([_employees count]==1)?@"":@"s")];
                } else if (_pageType == kEmployeeSearchViewPageTypeColleagues) {
                    pageTitle.text = [[NSString alloc] initWithFormat:@"%@'s Peer%@:", ([_titleName length]<7)?_titleName:[[_titleName componentsSeparatedByString:@" "] objectAtIndex:0], (([_employees count]==1)?@"":@"s")];
                }
            }
            [sortSection addSubview:pageTitle];
            
            UIView *buttonContainer = [[UIView alloc] initWithFrame:CGRectMake(([[UIScreen mainScreen] bounds].size.width/2)-64.0f, 54.0f, 128.0f, 46.0f)];
            
            UIButton *atozSort = [UIButton buttonWithType:UIButtonTypeCustom];
            atozSort.tag = ATOZ_TAG;
            atozSort.backgroundColor = [UIColor lightGrayColor];
            [atozSort addTarget:self action:@selector(sortClicked:) forControlEvents:UIControlEventTouchUpInside];
            [atozSort setImage:[UIImage imageNamed:@"icon_atoz.png"] forState:UIControlStateNormal];
            [atozSort setImageEdgeInsets:UIEdgeInsetsMake(11.0, 20.0, 11.0, 20.0)];
            atozSort.frame = CGRectMake(0.0f, 0.0f, 64.0f, 46.0f);
            //[atozSort setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [buttonContainer addSubview:atozSort];
            
            UIButton *locSort = [UIButton buttonWithType:UIButtonTypeCustom];
            locSort.tag = LOC_TAG;
            locSort.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"pipe.png"]];
            [locSort addTarget:self action:@selector(sortClicked:) forControlEvents:UIControlEventTouchUpInside];
            [locSort setImage:[UIImage imageNamed:@"icon_office.png"] forState:
             UIControlStateNormal];
            [locSort setImageEdgeInsets:UIEdgeInsetsMake(11.0, 20.0, 11.0, 20.0)];
            locSort.frame = CGRectMake(64.0f, 0.0f, 64.0f, 46.0f);
            //[locSort setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [buttonContainer addSubview:locSort];
            buttonContainer.layer.cornerRadius = 10.0f;
            buttonContainer.clipsToBounds = YES;
            
            CAShapeLayer *strokeLayer = [CAShapeLayer layer];
            strokeLayer.path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(([[UIScreen mainScreen] bounds].size.width/2)-64.0f, 54.0f, 128.0f, 46.0f) byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(10.0, 10.0)].CGPath;
            strokeLayer.fillColor = [UIColor clearColor].CGColor;
            strokeLayer.strokeColor = [UIColor lightGrayColor].CGColor;
            strokeLayer.lineWidth = 2;
            UIView *strokeView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 128.0f, 46.0f)];
            strokeView.userInteractionEnabled = NO;
            [strokeView.layer addSublayer:strokeLayer];
            [cell addSubview:strokeView];
            
            [sortSection addSubview:buttonContainer];
            [cell addSubview:sortSection];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        return cell;
    }
    
    /*if ([_employees count] > 1 && indexPath.row != 0 && indexPath.row != [_employees count]-1) {
        CellIdentifier = @"middleCell";
    } else {
        if ([_employees count] > 1) {
            if (indexPath.row == 0) {
                CellIdentifier = @"topCell";
            } else if (indexPath.row == [_employees count]-1) {
                CellIdentifier = @"bottomCell";
            }
        } else {
            CellIdentifier = @"singleCell";
        }
    }*/
    CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[EmployeeListCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        //cell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
        
        // best solution, works (borders are not fine but performance-wise, there is a significant difference :( ).
        // !!!: find a way to draw borders
        cell.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"pipe.png"]];
        if (_pageType != kEmployeeSearchViewPageTypeSearch) {
            cell.imageView.layer.cornerRadius = 5.0f;
            cell.imageView.clipsToBounds = YES;
        } else {
            cell.detailTextLabel.backgroundColor = [UIColor clearColor];
            cell.textLabel.backgroundColor = [UIColor clearColor];
        }
        
        
        /*CGFloat widthDiff = 18.0f; // don't like hardcoding this. find a way to calculate!
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            widthDiff = 88.0f; // grouped tableview ipad cell width = (screen width - 88)
        }
        NSLog(@"Cell Bounds: %@", NSStringFromCGRect(cell.bounds));
        CGRect origFrame = cell.bounds;
        origFrame.size.width = cell.bounds.size.width - widthDiff;
        origFrame.size.height = 44.0f;//cell.bounds.size.height + 1; // !!!: don't know why this +1 fixes. my border width (layers line width below)?
        
        // set background image
        UIImageView *bgImg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pipe.png"]];
        [bgImg setFrame:origFrame];
        cell.backgroundView = bgImg;
        
        // round top corners of cell 0 and bottom corners of cell N
        UIBezierPath *maskPath;
        CAShapeLayer *maskLayer = [CAShapeLayer layer];
        maskLayer.frame = origFrame;
        UIRectCorner corner = UIRectCornerAllCorners;
        //NSLog(@"Cell BG Bounds: %@", NSStringFromCGRect(origFrame));
        
        if ([_employees count] > 1 && indexPath.row != 0 && indexPath.row != [_employees count]-1) {
            maskPath = [UIBezierPath bezierPathWithRect:origFrame];
        } else {
            if ([_employees count] > 1) {
                if (indexPath.row == 0) {
                    corner = (UIRectCornerTopLeft| UIRectCornerTopRight);
                } else if (indexPath.row == [_employees count]-1) {
                    corner = (UIRectCornerBottomLeft| UIRectCornerBottomRight);
                }
            }
            maskPath = [UIBezierPath bezierPathWithRoundedRect:origFrame byRoundingCorners:corner cornerRadii:CGSizeMake(10.0, 10.0)];
        }
        maskLayer.path = maskPath.CGPath;
        cell.backgroundView.layer.mask = maskLayer;
        
        // draw border
        CAShapeLayer *strokeLayer = [CAShapeLayer layer];
        strokeLayer.path = maskPath.CGPath;
        strokeLayer.fillColor = [UIColor clearColor].CGColor;
        strokeLayer.strokeColor = [UIColor lightGrayColor].CGColor;
        strokeLayer.lineWidth = 2;
        UIView *strokeView = [[UIView alloc] initWithFrame:origFrame];
        strokeView.userInteractionEnabled = NO;
        [strokeView.layer addSublayer:strokeLayer];
        [cell.backgroundView addSubview:strokeView];*/
    }
    
    /*
     * well, i tried to round the top and bottom corners only, weird cell height changes (even if i set through heightforrowatindexpath) is a problem
     * UX decision: using it as it is.
     * <!--- leaving this for a better solution --->
     */
//    cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pipe.png"]];
//    
//    // !!!: not sure if creating dedicated cells for top, middle and bottom rows is more efficient in terms of performance. for now i am setting the rounded corners on the go.
//    UIBezierPath *maskPath;
//    CAShapeLayer *maskLayer = [CAShapeLayer layer];
//    maskLayer.frame = cell.backgroundView.bounds;
//    UIRectCorner corner = UIRectCornerAllCorners;
//    //NSLog(@"Cell Bounds: %@", NSStringFromCGRect(cell.bounds));
//    
//    if ([_employees count] > 1 && indexPath.row != 0 && indexPath.row != [_employees count]-1) {
//        maskPath = [UIBezierPath bezierPathWithRect:CGRectMake(0.0f, 0.0f, [[UIScreen mainScreen] bounds].size.width-widthDiff, 46.0f)];
//    } else {
//        if ([_employees count] > 1) {
//            if (indexPath.row == 0) {
//                corner = (UIRectCornerTopLeft| UIRectCornerTopRight);
//            } else if (indexPath.row == [_employees count]-1) {
//                corner = (UIRectCornerBottomLeft| UIRectCornerBottomRight);
//            }
//        }
//        /*
//         * NSLog(@"Cell Bounds: %@", NSStringFromCGRect(cell.bounds));
//         *
//         * NSLog(@"Cell Backgroundview Bounds: %@", NSStringFromCGRect(cell.backgroundView.bounds));
//         *
//         * !!!: there is a really strange behavior here. cell.backgroundview frame is sth strange on the first load, cell frame is always weird (although everything on ui is always fine).
//         * now hardcoding the CGRect, but ideally it should use cell.backgroundview frame for mask path
//         * width comes from grouped tableview's default cell width (screen width - 18), and height comes from grouped tableview's default cell height (46)
//         *
//         */
//        maskPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.0f, 0.0f, [[UIScreen mainScreen] bounds].size.width-widthDiff, 46.0f) byRoundingCorners:corner cornerRadii:CGSizeMake(10.0, 10.0)];
//    }
//    maskLayer.path = maskPath.CGPath;
//    cell.backgroundView.layer.mask = maskLayer;
//
//    // draw border
//    CAShapeLayer *strokeLayer = [CAShapeLayer layer];
//    strokeLayer.path = maskPath.CGPath;
//    strokeLayer.fillColor = [UIColor clearColor].CGColor;
//    strokeLayer.strokeColor = [UIColor lightGrayColor].CGColor;
//    strokeLayer.lineWidth = 2;
//    UIView *strokeView = [[UIView alloc] initWithFrame:cell.backgroundView.bounds];
//    strokeView.userInteractionEnabled = NO;
//    [strokeView.layer addSublayer:strokeLayer];
//    [cell.backgroundView addSubview:strokeView];
    
    if (![_employees count]) {
        switch (_pageType) {
            case kEmployeeSearchViewPageTypeSearch:
                cell.textLabel.text = @"search employees by first name";
                break;
                
            case kEmployeeSearchViewPageTypeColleagues:
                cell.textLabel.text = @"No Colleagues";
                break;
                
            case kEmployeeSearchViewPageTypeDReports:
                cell.textLabel.text = @"No Direct Reports";
                break;
                
            default:
                cell.textLabel.text = nil;
                break;
        }
        cell.detailTextLabel.text = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        NSUInteger row = [indexPath row];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        id employee;
        if (_pageType == kEmployeeSearchViewPageTypeSearch || !_pageSubtypeSortTypeIsLocation) {
            employee = [_employees objectAtIndex:row];
        } else {
            employee = [((RHLocation *)[locBasedSortResult objectAtIndex:(indexPath.section-1)]).employeeList objectAtIndex:indexPath.row];
        }
        
        cell.textLabel.text = [employee objectForKey:@"cn"];
        if (_pageType != kEmployeeSearchViewPageTypeSearch) {
            if ([employee objectForKey:@"title"] && ![[employee objectForKey:@"title"] isEqual:[NSNull null]] && [[employee objectForKey:@"title"] length]) {
                cell.detailTextLabel.text = [employee objectForKey:@"title"];
            }

            // !!!: calling offline data provider each time costs a lot. get rid of it soon. (found a workaround for now - still need to lazy load the image url as scrolling for the first time still is not smooth enough)
            // !!!: if img_path does not exist on data provider, should i read from pipe?
            if (!([employee objectForKey:@"profile_image_path"] && [[employee objectForKey:@"profile_image_path"] length])) {
                [cell.imageView setImage:[UIImage imageNamed:@"StaffAppIcon_HiRes_v2.png"]];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    id img_path = [[OfflineDataProvider sharedInstance] getProfileImagePath:employee];
                    id employeeToUpdate = [employee mutableCopy];
                    bool needsReload = false;
                    if (img_path) {
                        [employeeToUpdate setObject:img_path forKey:@"profile_image_path"];
                        needsReload = true;
                    } else {
                        // !!!: a workaround for non-existing profile images. sdwebimage uses strict caching, means if url matches, it always uses the cached copy. so i can leverage on this for my workaround.
                        // here i am NOT modifying the employee on the provider, just placeholding the image url for this VC
                        [employeeToUpdate setObject:[NSString stringWithFormat:@"%@img/placeholder", kRESTfulBaseURL] forKey:@"profile_image_path"];
                    }
                    // !!!: modifying the data source? check if this is safe.
                    if (!_pageSubtypeSortTypeIsLocation) {
                        [_employees replaceObjectAtIndex:row withObject:employeeToUpdate];
                    } else {
                        [((RHLocation *)[locBasedSortResult objectAtIndex:(indexPath.section-1)]).employeeList replaceObjectAtIndex:row withObject:employeeToUpdate];
                    }
                    if (needsReload) {
                        [self performSelectorOnMainThread:@selector(reloadRowAtIndexPathForProfileImage:) withObject:indexPath waitUntilDone:NO];
                    }
                });
            } else {
                [cell.imageView setImageWithURL:[NSURL URLWithString:[employee objectForKey:@"profile_image_path"]] placeholderImage:[UIImage imageNamed:@"profile_placeholder.png"]];
            }
            //[cell.imageView setImageWithURL:[NSURL URLWithString:[[OfflineDataProvider sharedInstance] getProfileImagePath:employee]] placeholderImage:[UIImage imageNamed:@"StaffAppIcon_HiRes_v2.png"]];
        } else {
            cell.detailTextLabel.text = nil;
        }
    }
//    NSLog(@"Cell Height: %f BG Height: %f", cell.bounds.size.height, cell.backgroundView.bounds.size.height);
    return cell;
}

- (void)reloadRowAtIndexPathForProfileImage:(NSIndexPath *)indexPath {
    if ([self.tableView.indexPathsForVisibleRows containsObject:indexPath]) {
        @synchronized(self){ // do i need this? check.
            [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:NO];
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) { // by this we have no header on searchview, and no header for the first sections of other views
        return nil;
    }
    if (_pageSubtypeSortTypeIsLocation) {
        return ((RHLocation *)[locBasedSortResult objectAtIndex:(section-1)]).locName;
    }
    return nil;
}

// UX decision: no footers
//- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
//    if (_pageType == kEmployeeSearchViewPageTypeDReports && section > 0) {
//        if ([_employees count]) {
//            NSMutableDictionary *locationDict = [[NSMutableDictionary alloc] init];
//            NSMutableDictionary *titleDict = [[NSMutableDictionary alloc] init];
//            for (int i=0; i<[_employees count]; i++) {
//                if ([locationDict objectForKey:[[_employees objectAtIndex:i] objectForKey:@"rhatlocation"]]) {
//                    [locationDict setObject:[NSNumber numberWithInteger:[[locationDict objectForKey:[[_employees objectAtIndex:i] objectForKey:@"rhatlocation"]] integerValue]+1] forKey:[[_employees objectAtIndex:i] objectForKey:@"rhatlocation"]];
//                } else {
//                    [locationDict setObject:[NSNumber numberWithInteger:1] forKey:[[_employees objectAtIndex:i] objectForKey:@"rhatlocation"]];
//                }
//                if ([[_employees objectAtIndex:i] objectForKey:@"title"] != [NSNull null] && [[[_employees objectAtIndex:i] objectForKey:@"title"] length]) {
//                    if ([titleDict objectForKey:[[_employees objectAtIndex:i] objectForKey:@"title"]]) {
//                        [titleDict setObject:[NSNumber numberWithInteger:[[titleDict objectForKey:[[_employees objectAtIndex:i] objectForKey:@"title"]] integerValue]+1] forKey:[[_employees objectAtIndex:i] objectForKey:@"title"]];
//                    } else {
//                        [titleDict setObject:[NSNumber numberWithInteger:1] forKey:[[_employees objectAtIndex:i] objectForKey:@"title"]];
//                    }
//                }
//            }
//            NSMutableString *statsStr = [[NSMutableString alloc] initWithString:@"\nDirect Reports From:\n\n"];
//            for (id key in locationDict) {
//                [statsStr appendFormat:@"%@ => %@\n\n", [locationDict objectForKey:key], key];
//            }
//            [statsStr appendString:@"\n\nDirect Reports Titles:\n\n"];
//            for (id key in titleDict) {
//                [statsStr appendFormat:@"%@ => %@\n\n", [titleDict objectForKey:key], key];
//            }
//            return statsStr;
//        }
//    }
//    return nil;
//}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![_employees count]) {
        return;
    }
    if (_pageType != kEmployeeSearchViewPageTypeSearch && indexPath.section == 0) {
        return;
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    id employee;
    if (_pageType == kEmployeeSearchViewPageTypeSearch || !_pageSubtypeSortTypeIsLocation) {
        employee = [_employees objectAtIndex:indexPath.row];
    } else {
        employee = [((RHLocation *)[locBasedSortResult objectAtIndex:(indexPath.section-1)]).employeeList objectAtIndex:indexPath.row];
    }
    
    StaffDetailTableViewController *detailViewController = [[StaffDetailTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    detailViewController.employee = employee;
    
    [self.navigationController pushViewController:detailViewController animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_pageType == kEmployeeSearchViewPageTypeSearch || indexPath.section > 0) {
        return UITableViewAutomaticDimension;
    }
    return 118.0f;
}

// leaving this for a better solution
// this is a dummy fix for strange (for now to me) cell height behavior.
//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
//    // !!!: WHY? i couldn't find why it changes the height of the cell (even if i set it while creating). :(
//    //return 46.0f;//(indexPath.row == 0)?44.0f:45.0f;
//    UITableViewCell *cell = [self tableView:tableView
//                      cellForRowAtIndexPath:indexPath];
//    NSLog(@"Cell Frame: %@", NSStringFromCGRect(cell.bounds));
//    return cell.bounds.size.height;
//}

@end