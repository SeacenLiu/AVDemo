//
//  ViewController.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/1/30.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "ViewController.h"
#import "AUPCMPlayerViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        // 音频播放
        if (indexPath.row == 0) {
            // AudioUnit 播放 PCM 文件
            AUPCMPlayerViewController *vc = [AUPCMPlayerViewController new];
            [self.navigationController pushViewController:vc animated:YES];
        }
    }
}

@end
