//  StaffRosterAPIClient.m
//
//  Generated by the the JBoss AeroGear Xcode Project Template on 5/23/13.
//  See Project's web site for more details http://www.aerogear.org
//

#import "StaffRosterAPIClient.h"

static NSString * const kStaffRosterAPIBaseURLString = kRESTfulBaseURL;

@implementation StaffRosterAPIClient

@synthesize employeesPipe = _employeesPipe;
@synthesize managerPipe = _managerPipe;
@synthesize colleaguesPipe = _colleaguesPipe;
@synthesize dreportsPipe = _dreportsPipe;
@synthesize syncCheckPipe = _syncCheckPipe;
@synthesize offlineDataPipe = _offlineDataPipe;

+ (StaffRosterAPIClient *)sharedInstance {
    static StaffRosterAPIClient *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] initWithBaseURL:[NSURL URLWithString:kStaffRosterAPIBaseURLString]];
    });
    
    return _sharedInstance;
}

- (id)initWithBaseURL:(NSURL *)url {
    if (self = [super init]) {
        
        // create the Pipeline object pointing to the remote application
        AGPipeline *pipeline = [AGPipeline pipelineWithBaseURL:[NSURL URLWithString:kStaffRosterAPIBaseURLString]];
        
        // once pipeline is constructed setup the pipes that will
        // point to the remote application REST endpoints
        _employeesPipe = [pipeline pipe:^(id<AGPipeConfig> config) {
            [config setName:@"employees"];
            [config setEndpoint:@"get_data_simple.php"];
        }];
        
        // ...any other pipes
        _managerPipe = [pipeline pipe:^(id<AGPipeConfig> config) {
            [config setName:@"manager"];
            [config setEndpoint:@"get_manager.php"];
        }];
        
        _colleaguesPipe = [pipeline pipe:^(id<AGPipeConfig> config) {
            [config setName:@"colleagues"];
            [config setEndpoint:@"get_colleagues.php"];
        }];
        
        _dreportsPipe = [pipeline pipe:^(id<AGPipeConfig> config) {
            [config setName:@"dreports"];
            [config setEndpoint:@"get_dreports.php"];
        }];
        
        _syncCheckPipe = [pipeline pipe:^(id<AGPipeConfig> config) {
            [config setName:@"sync_check"];
            [config setEndpoint:@"check_sync_time.php"];
        }];
        
        _offlineDataPipe = [pipeline pipe:^(id<AGPipeConfig> config) {
            [config setName:@"sync_employees"];
            [config setEndpoint:@"get_offline_data.php"];
        }];
    }
    
    return self;
}
@end
