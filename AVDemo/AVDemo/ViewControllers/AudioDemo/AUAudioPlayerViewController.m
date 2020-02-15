//
//  AUAudioPlayerViewController.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/1.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUAudioPlayerViewController.h"
#import "NSString+Path.h"
#import "AUAudioPlayer.h"

@interface AUAudioPlayerViewController ()

@end

@implementation AUAudioPlayerViewController
{
    AUAudioPlayer*            _audioPlayer;
}

- (IBAction)playClick:(id)sender {
    NSLog(@"Play Music...");
    NSString* filePath = [NSString bundlePath:@"spark.aac"];
    // TODO: - 对文件不存在的情况进行兜底处理
    _audioPlayer = [[AUAudioPlayer alloc] initWithFilePath:filePath];
    [_audioPlayer start];
}

- (IBAction)stopClick:(id)sender {
    NSLog(@"Stop Music...");
    if(_audioPlayer) {
        [_audioPlayer stop];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

@end
