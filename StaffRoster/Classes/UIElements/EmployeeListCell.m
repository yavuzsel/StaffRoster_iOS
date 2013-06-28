//
//  EmployeeListCell.m
//  StaffRoster
//
//  Created by yavuz on 6/24/13.
//  Copyright (c) 2013 redhat. All rights reserved.
//
/*
 * custom cell was required to set the frame of the cell's imageview
 * (look for a better -in terms  of performance- solution)
 */

#import "EmployeeListCell.h"

@implementation EmployeeListCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.frame.size.height == 64) { // inset the profile image and fix the label positioning problem (when not in search view -> height == 64)
        self.imageView.frame = CGRectMake(16,14,48,36);
        self.textLabel.frame = CGRectMake(74,13,[UIScreen mainScreen].bounds.size.width-110,22);
        self.detailTextLabel.frame = CGRectMake(74,35,[UIScreen mainScreen].bounds.size.width-110,18);
    }
}

@end
