//  StaffRosterAPIClient.h
//
//  Generated by the the JBoss AeroGear Xcode Project Template on 5/23/13.
//  See Project's web site for more details http://www.aerogear.org
//

#import "AeroGear.h"

@interface StaffRosterAPIClient : NSObject

@property(readonly, nonatomic) id<AGPipe> employeesPipe;

@property(readonly, nonatomic) id<AGPipe> managerPipe;

@property(readonly, nonatomic) id<AGPipe> colleaguesPipe;

@property(readonly, nonatomic) id<AGPipe> dreportsPipe;

@property(readonly, nonatomic) id<AGPipe> syncCheckPipe;

@property(readonly, nonatomic) id<AGPipe> offlineDataPipe;

@property(readonly, nonatomic) id<AGPipe> imageURLPipe;

+ (StaffRosterAPIClient *)sharedInstance;
@end
