//
//  JSSolutionMenuViewController.m
//  MultipleCameraFeeds
//
//  Created by Johnny Slagle on 7/27/14.
//  Copyright (c) 2014 Johnny Slagle. All rights reserved.
//

#import "JSSolutionMenuViewController.h"

#import "JSOpenGLFeedsViewController.h"
#import "JSReplicatorLayerViewController.h"

static NSString * const UITableViewCellIdentifier = @"UITableViewCellIdentifier";

typedef NS_ENUM(NSUInteger, SolutionMenuRow) {
    SolutionMenuRowReplicatorLayer,
    SolutionMenuRowOpenGL,
    NumberOfSolutionMenuRows
};

@implementation JSSolutionMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // UI
    self.title = @"Solutions";
    
    // Table View
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:UITableViewCellIdentifier];
}


#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return NumberOfSolutionMenuRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UITableViewCellIdentifier forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    if (indexPath.row == SolutionMenuRowReplicatorLayer) {
        cell.textLabel.text = @"CAReplicatorLayer Solution";
    } else if (indexPath.row == SolutionMenuRowOpenGL) {
        cell.textLabel.text = @"OpenGL Solution";
    }
    
    return cell;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == SolutionMenuRowReplicatorLayer) {
        JSReplicatorLayerViewController *replicatorViewController = [[JSReplicatorLayerViewController alloc] init];
        [self.navigationController pushViewController:replicatorViewController animated:YES];
    } else if (indexPath.row == SolutionMenuRowOpenGL) {
        JSOpenGLFeedsViewController *twoFeedsViewController = [[JSOpenGLFeedsViewController alloc] init];
        [self.navigationController pushViewController:twoFeedsViewController animated:YES];
    }
}

@end
