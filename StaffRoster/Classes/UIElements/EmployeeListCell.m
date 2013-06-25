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
    self.imageView.frame = CGRectMake(16,14,48,36);
}

@end
