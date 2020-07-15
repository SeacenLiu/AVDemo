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
#import "AUAudioRecorderViewController.h"
#import "SCAudioRecorderViewController.h"

#import "PngPreviewViewController.h"

#import "SCVideoPlayerTestViewController.h"

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
    } else if (indexPath.section == 1) {
        // 音频采集 - AudioToolbox
        if (indexPath.row == 0) {
            // AudioUnit 录制音频并保存为 caf 文件
            AUAudioRecorderViewController *vc = [AUAudioRecorderViewController new];
            [self.navigationController pushViewController:vc animated:YES];
        }
    } else if (indexPath.section == 2) {
        // 音频综合处理 - AudioToolbox
        if (indexPath.row == 0) {
            // AudioUnit 录音 + 背景音乐
            SCAudioRecorderViewController *vc = [SCAudioRecorderViewController new];
            [self.navigationController pushViewController:vc animated:YES];
        }
    } else if (indexPath.section == 3) {
        // OpenGL渲染 - OpenGLES
        if (indexPath.row == 0) {
            // OpenGL 渲染 png 图片
            PngPreviewViewController *vc = [PngPreviewViewController new];
            [self.navigationController pushViewController:vc animated:YES];
        }
    } else if (indexPath.section == 4) {
        // 视频播放 - 音频+视频结合
        if (indexPath.row == 0) {
            // 本地 FLV 文件视频播放
            SCVideoPlayerTestViewController *vc = [SCVideoPlayerTestViewController new];
            [self.navigationController pushViewController:vc animated:YES];
        }
    }
}

@end
