//
//  ViewController.m
//  AUPCMPlayer
//
//  Created by bobo on 2019/12/3.
//  Copyright © 2019年 seacenliu. All rights reserved.
//

#import "ViewController.h"
#import "SCPlayer.h"

@interface ViewController () <SCPlayerDelegate>
@property (nonatomic, strong) SCPlayer *player;

@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (weak, nonatomic) IBOutlet UIButton *stopBtn;
@property (weak, nonatomic) IBOutlet UIButton *endBtn;

@end

@implementation ViewController

- (IBAction)playClick:(id)sender {
    [_player play];
}

- (IBAction)stopClick:(id)sender {
    [_player stop];
}

- (IBAction)endClick:(id)sender {
    [_player end];
}

- (void)initBtnStatus {
    _playBtn.enabled = YES;
    _stopBtn.enabled = NO;
    _endBtn.enabled = NO;
}

- (void)onPlayerRefreshStatus:(SCPlayer *)player status:(SCPlayerStatus)status {
    switch (status) {
        case SCPlayerStatusPlay:
            _playBtn.enabled = NO;
            _stopBtn.enabled = YES;
            _endBtn.enabled = YES;
            break;
        case SCPlayerStatusStop:
            _playBtn.enabled = YES;
            _stopBtn.enabled = NO;
            _endBtn.enabled = YES;
        case SCPlayerStatusEnd:
        case SCPlayerStatusUnknow:
        default:
            _playBtn.enabled = YES;
            _stopBtn.enabled = NO;
            _endBtn.enabled = NO;
            break;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"pcm"];
    _player = [[SCPlayer alloc] initWithFileURL:url];
    _player.delegate = self;
    
    [self initBtnStatus];
}


@end
