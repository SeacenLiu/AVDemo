//
//  AUGraphPlayerViewController.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/1/30.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "AUGraphPlayerViewController.h"
#import "AUGraphPlayer.h"
#import "NSString+Path.h"

@interface AUGraphPlayerViewController ()
@property(nonatomic, assign) BOOL isAcc;
@end

@implementation AUGraphPlayerViewController

{
    AUGraphPlayer*                  graphPlayer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _isAcc = NO;
}

- (IBAction)playMusic:(id)sender {
    NSLog(@"Play Music...");
    if(graphPlayer) {
        [graphPlayer stop];
    }
    NSString* filePath = [NSString bundlePath:@"test2.mp3"];
    graphPlayer = [[AUGraphPlayer alloc] initWithFilePath:filePath];
    [graphPlayer play];
}

- (IBAction)switchAction:(id)sender {
    _isAcc = !_isAcc;
    [graphPlayer setInputSource:_isAcc];
}

- (IBAction)stopMusic:(id)sender {
    NSLog(@"Stop Music...");
    [graphPlayer stop];
}


@end
