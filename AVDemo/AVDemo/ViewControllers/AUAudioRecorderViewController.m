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
    _recorder = [[AUAudioRecorder alloc] initWithPath:filePath];
    [_btn setTitle:startText forState:UIControlStateNormal];
}

@end
