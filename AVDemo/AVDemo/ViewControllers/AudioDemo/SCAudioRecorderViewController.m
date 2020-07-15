//
//  SCAudioRecorderViewController.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/8.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "SCAudioRecorderViewController.h"
#import "SCAudioRecorder.h"
#import "NSString+Path.h"

static NSString * const startText = @"Start";
static NSString * const stopText = @"Stop";

@interface SCAudioRecorderViewController () <SCAudioRecorderDelegate>

@property (weak, nonatomic) IBOutlet UIButton *btn;
@property (nonatomic, strong) SCAudioRecorder *recorder;
@property (weak, nonatomic) IBOutlet UISlider *progressSlider;

@end

@implementation SCAudioRecorderViewController

- (IBAction)playMusicBtnClick:(id)sender {
    //        NSString *musicPath = [NSString bundlePath:@"heart.mp3"];
    NSString *musicPath = [NSString bundlePath:@"background.mp3"];
    [_recorder playMusicWithPath:musicPath];
}

- (IBAction)endMusicBtnClick:(id)sender {
    [_recorder endPlayMusic];
}

- (IBAction)musicVolumeValueChange:(UISlider*)sender {
    _recorder.musicVolume = sender.value;
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
    } else if ([sender.titleLabel.text isEqualToString:stopText]) { // 停止录音
        [_recorder stopRecord];
        [sender setTitle:startText forState:UIControlStateNormal];
    } else {
        
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString* filePath = [NSString documentsPath:@"recorder.caf"];
    NSLog(@"%@", filePath);
    _recorder = [[SCAudioRecorder alloc] initWithPath:filePath];
    _recorder.delegate = self;
    [_btn setTitle:startText forState:UIControlStateNormal];
}

- (void)dealloc {
    
}

#pragma mark - SCAudioRecorderDelegate
- (void)audioRecorderDidCompletePlay:(nonnull SCAudioRecorder *)recoder {
    NSLog(@"播放完毕");
}

- (void)audioRecorderDidLoadMusicFile:(nonnull SCAudioRecorder *)recoder {
    _progressSlider.value = 0;
}

- (void)audioRecorderDidPlayProgress:(nonnull SCAudioRecorder *)recoder
                            progress:(CGFloat)progress
                       currentSecond:(NSTimeInterval)currentSecond
                         totalSecond:(NSTimeInterval)totalSecond {
    _progressSlider.value = progress;
}

@end