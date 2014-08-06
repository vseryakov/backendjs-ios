//
//  BKChart.h
//
//  Created by Vlad Seryakov 7/10/14.
//  Copyright (c) 2014. All rights reserved.
//
//  Based on PNChart project: https://github.com/kevinzhow/PNChart
//

@interface BKProgressLabel : UILabel
@property (nonatomic, assign) double startValue;
@property (nonatomic, assign) double endValue;
@property (nonatomic, assign) double duration;
@property (nonatomic, assign) NSString *method;
@property (nonatomic, strong) NSString *format;
@property (nonatomic, strong) SuccessBlock completionHandler;
-(void)countFrom:(float)from to:(float)to duration:(NSTimeInterval)duration;
@end

@interface BKBarChart : UIView
@property (nonatomic) float barWidth;
@property (strong, nonatomic) NSArray *xLabels;
@property (strong, nonatomic) NSArray *yValues;
@property (nonatomic, strong) UIColor *barColor;
@property (nonatomic, strong) UIColor *axisColor;
@property (nonatomic, strong) NSDictionary *colors;
@property (nonatomic, strong) SuccessBlock completionHandler;
- (void)drawChart;
@end

@interface BKLineChart : UIView
@property (strong, nonatomic) NSArray *xLabels;
@property (strong, nonatomic) NSArray *yValues;
@property (nonatomic, strong) UIColor *lineColor;
@property (nonatomic, strong) UIColor *axisColor;
@property (nonatomic, strong) SuccessBlock completionHandler;
- (void)drawChart;
@end

@interface BKCircleChart : UIView
@property (nonatomic, strong) UIColor *bgColor;
@property (nonatomic, strong) UIColor *totalColor;
@property (nonatomic, strong) UIColor *currentColor;
@property (nonatomic, strong) UIColor *axisColor;
@property (nonatomic) float axisFontSize;
@property (nonatomic) float total;
@property (nonatomic) float current;
@property (nonatomic) float lineWidth;
@property (nonatomic, strong) BKProgressLabel* label;
@property (nonatomic, strong) SuccessBlock completionHandler;
- (void)drawChart;
@end

