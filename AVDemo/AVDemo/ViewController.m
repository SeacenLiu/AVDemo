//
//  ViewController.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/1/30.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "ViewController.h"
#import "AUPCMPlayerViewController.h"
#import "AUGraphPlayerViewController.h"
#import "AUAudioPlayerViewController.h"

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
        // 音频播放 - AudioToolbox
        if (indexPath.row == 0) {
            // AudioUnit 播放 PCM 文件(by NSInputStream)
            AUPCMPlayerViewController *vc = [AUPCMPlayerViewController new];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (indexPath.row == 1) {
            // AUGraph 播放 MP3 文件(by AudioFilePlayer)
            AUGraphPlayerViewController *vc = [AUGraphPlayerViewController new];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (indexPath.row == 2) {
            // AudioUnit 播放 ACC 文件(by ffmpeg decode)
            AUAudioPlayerViewController *vc = [AUAudioPlayerViewController new];
            [self.navigationController pushViewController:vc animated:YES];
        }
    }
}

@end