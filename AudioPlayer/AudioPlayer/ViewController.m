//
//  ViewController.m
//  AudioPlayer
//
//  Created by SeacenLiu on 2019/11/14.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "ViewController.h"
#import "SCAudioPlayer.h"
#import "NSString+Path.h"

@interface ViewController ()

@end

@implementation ViewController
{
    SCAudioPlayer*            _audioPlayer;
}

- (IBAction)playClick:(id)sender {
    NSLog(@"Play Music...");
    //    NSString* filePath = [NSString bundlePath:@"131.aac"];
//    NSString* filePath = [NSString bundlePath:@"111.aac"];
    NSString* filePath = [NSString bundlePath:@"test.aac"];
    // TODO: - 对文件不存在的情况进行兜底处理
    _audioPlayer = [[SCAudioPlayer alloc] initWithFilePath:filePath];
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
    // Do any additional setup after loading the view.
}


@end
