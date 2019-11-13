//
//  ViewController.m
//  AUPlayer
//
//  Created by SeacenLiu on 2019/6/12.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "ViewController.h"
#import "AUGraphPlayer.h"
#import "NSString+Path.h"

@interface ViewController ()
@property(nonatomic, assign) BOOL isAcc;
@end

@implementation ViewController
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
//    NSString* filePath = [NSString bundlePath:@"test.mp3"];
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
