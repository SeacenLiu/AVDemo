//
//  AUAudioRecorderViewController.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/1.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUAudioRecorderViewController.h"
#import "AUAudioRecorder.h"
#import "NSString+Path.h"

NSString * const startText = @"Start";
NSString * const stopText = @"Stop";

@interface AUAudioRecorderViewController ()

@property (weak, nonatomic) IBOutlet UIButton *btn;
@property (nonatomic, strong) AUAudioRecorder *recorder;
@property (weak, nonatomic) IBOutlet UISlider *musicSlider;
@property (weak, nonatomic) IBOutlet UISlider *progressSlider;

@property (nonatomic, strong) NSTimer *timer;

@end

@implementation AUAudioRecorderViewController

- (IBAction)playMusicBtnClick:(id)sender {
    //        NSString *musicPath = [NSString bundlePath:@"heart.mp3"];
    NSString *musicPath = [NSString bundlePath:@"background.mp3"];
    [_recorder playMusicWithPath:musicPath];
}

- (IBAction)stopMusicBtnClick:(id)sender {
    [_recorder endPlayMusic];
}

- (IBAction)bgmVolumeValueChange:(UISlider*)sender {
    _recorder.bgmVolume = sender.value;
}

- (IBAction)voiceVolumeValueChange:(UISlider*)sender {
    _recorder.voiceVolume = sender.value;
}

- (IBAction)enablePlayWhenRecorAction:(UISwitch *)sender {
    _recorder.enablePlayWhenRecord = sender.isOn;
}

- (IBAction)btnClick:(UIButton*)sender {
    if ([sender.titleLabel.text isEqualToString:startText]) { // 开始录音
        [_recorder startRecord];
        [sender setTitle:stopText forState:UIControlStateNormal];
        
        self.timer = [NSTimer timerWithTimeInterval:1/24
                                             target:self
                                           selector:@selector(showCurrentTime)
                                           userInfo:nil
                                            repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
    } else if ([sender.titleLabel.text isEqualToString:stopText]) { // 停止录音
        [_recorder stopRecord];
        [sender setTitle:startText forState:UIControlStateNormal];
        [_timer invalidate];
    } else {
        
    }
}

- (void)showCurrentTime {
    NSTimeInterval all = _recorder.allTime;
    NSTimeInterval cur = _recorder.curTime;
    NSTimeInterval progress = cur / all;
    NSLog(@"%f = %f / %f", progress, cur, all);
    _progressSlider.value = progress;
}

- (IBAction)currentTimeAction:(id)sender {
    NSTimeInterval all = _recorder.allTime;
    NSTimeInterval cur = _recorder.curTime;
    NSTimeInterval progress = cur / all;
    NSLog(@"%f = %f / %f", progress, cur, all);
    _progressSlider.value = progress;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString* filePath = [NSString documentsPath:@"recorder.caf"];
    NSLog(@"%@", filePath);
    _recorder = [[AUAudioRecorder alloc] initWithPath:filePath];
    [_btn setTitle:startText forState:UIControlStateNormal];
}

- (void)dealloc {
    [_timer invalidate];
}

@end
