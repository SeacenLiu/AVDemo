//
//  ViewController.m
//  AudioRecorder
//
//  Created by SeacenLiu on 2019/12/5.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "ViewController.h"
#import "AudioRecorder.h"
#import "CommonUtil.h"

NSString * const startText = @"Start";
NSString * const stopText = @"Stop";

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIButton *btn;
@property (nonatomic, strong) AudioRecorder *recorder;

@end

@implementation ViewController

- (IBAction)btnClick:(UIButton*)sender {
    if ([sender.titleLabel.text isEqualToString:startText]) { // 开始录音
        [_recorder start];
        [sender setTitle:stopText forState:UIControlStateNormal];
    } else if ([sender.titleLabel.text isEqualToString:stopText]) { // 停止录音
        [_recorder stop];
        [sender setTitle:startText forState:UIControlStateNormal];
    } else {
        
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // /Users/cheng/Library/Developer/CoreSimulator/Devices/C35BCAAB-DAFE-4873-A6A9-72396E29C217/data/Containers/Data/Application/88FA5562-358C-43E9-9A95-91ECB5E71269/Documents
    NSString* filePath = [CommonUtil documentsPath:@"recorder.caf"];
    NSLog(@"%@", filePath);
    _recorder = [[AudioRecorder alloc] initWithPath:filePath];
    [_btn setTitle:startText forState:UIControlStateNormal];
}


@end
