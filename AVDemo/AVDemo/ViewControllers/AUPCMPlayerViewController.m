//
//  AUPCMPlayerViewController.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/1/30.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUPCMPlayerViewController.h"
#import "AUPCMPlayer.h"

@interface AUPCMPlayerViewController () <AUPCMPlayerDelegate>

@property (nonatomic, strong) AUPCMPlayer *player;

@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (weak, nonatomic) IBOutlet UIButton *stopBtn;
@property (weak, nonatomic) IBOutlet UIButton *endBtn;

@end

@implementation AUPCMPlayerViewController

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

#pragma mark - AUPCMPlayerDelegate
- (void)onPlayerRefreshStatus:(AUPCMPlayer *)player status:(AUPCMPlayerStatus)status {
    switch (status) {
        case AUPCMPlayerStatusPlay:
            _playBtn.enabled = NO;
            _stopBtn.enabled = YES;
            _endBtn.enabled = YES;
            break;
        case AUPCMPlayerStatusStop:
            _playBtn.enabled = YES;
            _stopBtn.enabled = NO;
            _endBtn.enabled = YES;
        case AUPCMPlayerStatusEnd:
        case AUPCMPlayerStatusUnknow:
        default:
            _playBtn.enabled = YES;
            _stopBtn.enabled = NO;
            _endBtn.enabled = NO;
            break;
    }
}

#pragma mark - view life cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"start-dash" withExtension:@"pcm"];
    _player = [[AUPCMPlayer alloc] initWithFileURL:url];
    _player.delegate = self;
    
    [self initBtnStatus];
}


@end
