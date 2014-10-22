//
//  BKChart.h
//
//  Created by Vlad Seryakov 7/10/14.
//  Copyright (c) 2014. All rights reserved.
//

#import "BKChart.h"

#define chartMargin      4
#define bottomMargin     16
#define DEGREES_TO_RADIANS(degrees) ((M_PI * degrees)/180.0)

@interface BKBar : UIView
@property (nonatomic, strong) CABasicAnimation *anim;
@end

@implementation BKBar {
    UIColor *_fillColor;
    CAShapeLayer *_line;
}
- (id)init:(CGRect)frame color:(UIColor*)color fillColor:(UIColor*)fillColor duration:(float)duration grade:(float)grade
{
    self = [super initWithFrame:frame];
    self.clipsToBounds = YES;
    self.layer.cornerRadius = 2.0;
    _fillColor = fillColor;
    
    _line = [CAShapeLayer layer];
    _line.strokeColor = color.CGColor;
    _line.lineCap = kCALineCapButt;
    _line.fillColor = fillColor.CGColor;
    _line.lineWidth = self.frame.size.width;
    _line.strokeEnd = 0.0;
    [self.layer addSublayer:_line];
    
	UIBezierPath *progressline = [UIBezierPath bezierPath];
    [progressline moveToPoint:CGPointMake(self.frame.size.width/2.0, self.frame.size.height)];
	[progressline addLineToPoint:CGPointMake(self.frame.size.width/2.0, (1 - grade) * self.frame.size.height)];
    [progressline setLineWidth:1.0];
    [progressline setLineCapStyle:kCGLineCapSquare];
	_line.path = progressline.CGPath;
    
    self.anim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    self.anim.duration = duration;
    self.anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    self.anim.fromValue = [NSNumber numberWithFloat:0.0f];
    self.anim.toValue = [NSNumber numberWithFloat:1.0f];
    self.anim.autoreverses = NO;
    [_line addAnimation:self.anim forKey:@"strokeEndAnimation"];
    _line.strokeEnd = 1.0;
    
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, _fillColor.CGColor);
	CGContextFillRect(context, rect);
}
@end

@implementation BKBarChart {
    float _xLabelWidth;
    float _chartHeight;
    float _bottomMargin;
    int _nbars;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.backgroundColor = [UIColor whiteColor];
    self.axisColor = [UIColor blackColor];
    self.barColor = [UIColor greenColor];
    self.fillColor = [UIColor whiteColor];
    self.barWidth = 10;
    self.duration = 1.0;
    self.clipsToBounds = YES;
    return self;
}

-(void)drawChart
{
    _nbars = 0;
    for (UIView *view in self.subviews) {
        [view removeFromSuperview];
    }
    _bottomMargin = self.axisFont ? self.axisFont.lineHeight * 2 : bottomMargin;
    _chartHeight = self.frame.size.height - chartMargin - _bottomMargin;
    int max = 5;
    for (int index = 0; index < _yValues.count; index++) {
        max = MAX(max, [_yValues[index] intValue]);
    }
    _xLabelWidth = (self.frame.size.width - chartMargin*2)/[_xLabels count];
    
    for (int index = 0; index < _xLabels.count; index++) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(index * _xLabelWidth + chartMargin, self.frame.size.height - _bottomMargin + 10, _xLabelWidth, _bottomMargin)];
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.numberOfLines = 0;
        label.font = self.axisFont ? self.axisFont : [UIFont systemFontOfSize:bottomMargin/2];
        label.minimumScaleFactor = label.font.lineHeight*0.5;
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = self.axisColor;
        label.text = _xLabels[index];
        [self addSubview:label];
    }

    for (int index = 0; index < _yValues.count; index++) {
        float value = [_yValues[index] floatValue];
        float grade = value / (float)max;
        UIColor *color = self.barColor;
        // Custom color for a bar
        if (self.colors && self.colors[[NSNumber numberWithInt:index]]) {
            color = self.colors[[NSNumber numberWithInt:index]];
        }
        BKBar *bar = [[BKBar alloc] init:CGRectMake(index * _xLabelWidth + chartMargin + _xLabelWidth/2 - self.barWidth/2, self.frame.size.height - _chartHeight - _bottomMargin, self.barWidth, _chartHeight)
                                   color:color
                               fillColor:self.fillColor
                                duration:self.duration
                                   grade:grade];
        bar.anim.delegate = self;
        bar.tag = index;
        if (self.shadowOffset) {
            [BKui setViewShadow:bar color:[UIColor grayColor] offset:CGSizeMake(-self.shadowOffset, self.shadowOffset) opacity:0.5 radius:self.shadowOffset];
        }
        if (self.barHandler) self.barHandler(bar);
		[self addSubview:bar];
        _nbars++;
    }
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    Logger(@"%d", _nbars);
    anim.delegate = nil;
    if (--_nbars == 0) return;
    if (self.completionHandler) self.completionHandler(self);
}

@end

@implementation BKLineChart

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.backgroundColor = [UIColor whiteColor];
    self.axisColor = [UIColor blackColor];
    self.lineColor = [UIColor whiteColor];
    self.lineWidth = 1;
    self.clipsToBounds = YES;
    
    return self;
}

-(void)drawChart
{
    if (!_yValues.count) return;
    
    for (UIView *view in self.subviews) {
        [view removeFromSuperview];
    }
    
    CAShapeLayer *chartLine = [CAShapeLayer layer];
    chartLine.lineCap = kCALineCapRound;
    chartLine.lineJoin = kCALineJoinBevel;
    chartLine.lineWidth = self.lineWidth;
    chartLine.strokeEnd = 0.0;
    chartLine.fillColor = [[UIColor whiteColor] CGColor];
    chartLine.strokeColor = [_lineColor CGColor];
    [self.layer addSublayer:chartLine];
    
    float max = self.yMax ? [self.yMax floatValue] : 5, min = self.yMin ? [self.yMin floatValue] : INT_MAX;
    for (int i = 0; i < _yValues.count; i++) {
        max = MAX(max, [_yValues[i] floatValue]);
        min = MIN(min, [_yValues[i] floatValue]);
    }
    if (min == max) max++;
    
    float chartHeight = self.frame.size.height - chartMargin - bottomMargin;
    float yLabelWidth = [[NSString stringWithFormat:@"%0.f", max] length] * bottomMargin/2;
    float xLabelWidth = (self.frame.size.width - chartMargin*2 - yLabelWidth)/[_xLabels count];
    
    for (int index = 0; index < _xLabels.count; index++) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(chartMargin + yLabelWidth + index * xLabelWidth, self.frame.size.height - bottomMargin - chartMargin + bottomMargin/4, xLabelWidth, bottomMargin)];
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.minimumScaleFactor = bottomMargin/2*0.5;
        label.numberOfLines = 0;
        label.font = [UIFont systemFontOfSize:bottomMargin/2];
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = self.axisColor;
        label.text = _xLabels[index];
        [self addSubview:label];
    }
    
    float yLabelStep = bottomMargin/2*3;
    int yCount = chartHeight / yLabelStep;
    float yValueStep = (max - min) / yCount;
	for (int index = 0; index <= yCount; index++) {
        float y = chartHeight - yLabelStep * index;
        // Keep edges within chart area
        if (y < chartMargin) y = chartMargin;
        if (y > chartHeight) y = chartHeight;
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(chartMargin, y, yLabelWidth, bottomMargin)];
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.minimumScaleFactor = bottomMargin/2*0.5;
        label.numberOfLines = 0;
        label.font = [UIFont systemFontOfSize:bottomMargin/2];
        label.textAlignment = NSTextAlignmentRight;
        label.textColor = self.axisColor;
		label.text = [NSString stringWithFormat:@"%1.f", yValueStep * index + min];
		[self addSubview:label];
	}
    
    UIGraphicsBeginImageContext(self.frame.size);
    UIBezierPath *progressline = [UIBezierPath bezierPath];
    float value = [[_yValues objectAtIndex:0] floatValue];
    float scale = (value - min) / (max - min);
    [progressline setLineWidth:3.0];
    [progressline setLineCapStyle:kCGLineCapRound];
    [progressline setLineJoinStyle:kCGLineJoinRound];
    [progressline moveToPoint:CGPointMake(chartMargin + yLabelWidth + xLabelWidth*0.5, chartHeight - scale * chartHeight + chartMargin)];

    for (int index = 1; index < _yValues.count; index++) {
        value = [_yValues[index ] floatValue];
        scale = (value - min) / (max - min);
        CGPoint point = CGPointMake(chartMargin + yLabelWidth + index * xLabelWidth + xLabelWidth*0.5, chartHeight - scale * chartHeight + chartMargin);
        [progressline addLineToPoint:point];
        [progressline moveToPoint:point];
        [progressline stroke];
        
        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(point.x - 3, point.y - 3, 6, 6)];
        dot.backgroundColor = _lineColor;
        dot.layer.cornerRadius = 3;
        [BKui setViewShadow:dot color:nil offset:CGSizeMake(0, 3) opacity:0.3 radius:3];
        [self addSubview:dot];
        
//        CAKeyframeAnimation *dotAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
//        dotAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
//        dotAnim.duration = 1.5;
//        dotAnim.autoreverses = NO;
//        dotAnim.values = @[ @(0), @(0.5), @(0.7), @(1), @(1.2), @(1)];
        
        CABasicAnimation *dotAnim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        dotAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        dotAnim.duration = 1.5;
        dotAnim.autoreverses = NO;
        dotAnim.fromValue = [NSNumber numberWithFloat:0];
        dotAnim.toValue = [NSNumber numberWithFloat:1];
        [dot.layer addAnimation:dotAnim forKey:@"scale"];
    }
    chartLine.path = progressline.CGPath;
    
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    anim.duration = 1.5;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.fromValue = [NSNumber numberWithFloat:0.0f];
    anim.toValue = [NSNumber numberWithFloat:1.0f];
    anim.autoreverses = NO;
    anim.delegate = self;
    [chartLine addAnimation:anim forKey:@"strokeEndAnimation"];
    chartLine.strokeEnd = 1.0;
    UIGraphicsEndImageContext();
}

- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
    if (self.completionHandler) self.completionHandler(self);
}

@end

@implementation BKRatioChart {
    CAShapeLayer *_totalLayer;
    CAShapeLayer *_currentLayer;
    CAGradientLayer *_gradientLayer;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.startValue = 0;
    self.endValue = 100;
    self.lineWidth = 3;
    self.color1 = [UIColor greenColor];
    self.color2 = [UIColor colorWithRed:90/255. green:198/255. blue:255/255. alpha:1.0];
    self.bgColor = nil;
    
    self.label = [[BKProgressLabel alloc] initWithFrame:self.frame];
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.method = @"EaseOut";
    self.label.format = @"%d%%";
    self.label.textColor = [UIColor blackColor];
    [self addSubview:self.label];

    _totalLayer = [CAShapeLayer layer];
    _totalLayer.lineCap = kCALineCapButt;
    _totalLayer.lineWidth = 0;
    _totalLayer.strokeEnd = 1.0;
    _totalLayer.zPosition = -1;
    [self.layer addSublayer:_totalLayer];
    
    _currentLayer = [CAShapeLayer layer];
    _currentLayer.lineCap = kCALineCapSquare;
    _currentLayer.fillColor = [UIColor clearColor].CGColor;
    _currentLayer.zPosition = 1;
    _currentLayer.lineCap = kCALineCapSquare;
    
    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.startPoint = CGPointMake(0, 0);
    _gradientLayer.endPoint = CGPointMake(1, 1);
    _gradientLayer.mask = _currentLayer;
    [self.layer addSublayer:_gradientLayer];

    return self;
}

-(void)drawChart
{
    float radius = self.frame.size.height * 0.5 - _lineWidth - chartMargin*2;

    self.label.frame = self.frame;
    self.label.center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);

    _totalLayer.path = [UIBezierPath bezierPathWithArcCenter:_label.center
                                                     radius:radius - _lineWidth/2 + 1
                                                 startAngle:DEGREES_TO_RADIANS(0)
                                                   endAngle:DEGREES_TO_RADIANS(360)
                                                  clockwise:NO].CGPath;
    _totalLayer.fillColor = _bgColor.CGColor;
    _totalLayer.strokeColor = _color1.CGColor;

    _currentLayer.path = [UIBezierPath bezierPathWithArcCenter:_label.center
                                                        radius:radius
                                                    startAngle:DEGREES_TO_RADIANS(0)
                                                      endAngle:DEGREES_TO_RADIANS(360)
                                                     clockwise:YES].CGPath;
    _currentLayer.strokeColor = _color2.CGColor;
    _currentLayer.lineWidth = _lineWidth;
    
    _gradientLayer.frame = self.bounds;
    _gradientLayer.colors = @[ (id)_color1.CGColor, (id)_color1.CGColor, (id)_color2.CGColor, (id)_color2.CGColor ];
    
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    anim.duration = 2.0;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    anim.fromValue = [NSNumber numberWithFloat:0.0f];
    anim.toValue = [NSNumber numberWithFloat:1.0f];
    anim.autoreverses = NO;
    anim.delegate = self;
    [_currentLayer addAnimation:anim forKey:@"strokeEndAnimation"];
    _currentLayer.strokeEnd = 1;
    
    [self.label countFrom:_startValue to:_endValue duration:anim.duration];
}

- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
    if (self.completionHandler) self.completionHandler(self);
}

@end;

@interface BKProgressLabel ()
@property NSTimeInterval progress;
@property NSTimeInterval lastUpdate;
@property float easingRate;
@end

@implementation BKProgressLabel

- (void)countFrom:(float)from to:(float)to duration:(NSTimeInterval)duration
{
    self.progress = 0;
    self.easingRate = 3.0f;
    self.startValue = from;
    self.endValue = to;
    self.duration = duration;
    self.lastUpdate = [NSDate timeIntervalSinceReferenceDate];
    if (self.format == nil) self.format = @"%f";
    
    NSTimer* timer = [NSTimer timerWithTimeInterval:(1.0f/30.0f) target:self selector:@selector(update:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)update:(NSTimer*)timer
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    self.progress += now - self.lastUpdate;
    self.lastUpdate = now;
    
    if (self.progress >= self.duration) {
        [timer invalidate];
        self.progress = self.duration;
    }
    float percent = self.progress / self.duration;
    float updateVal = percent;
    
    if ([self.method isEqualToString:@"EaseIn"]) {
        updateVal = powf(percent, self.easingRate);
    } else
    if ([self.method isEqualToString:@"EaseOut"]) {
        updateVal = 1.0 - powf((1.0 - percent), self.easingRate);
    } else
    if ([self.method isEqualToString:@"EaseInOut"]) {
        int sign = ((int)self.easingRate) % 2 == 0 ? -1 : 1;
        percent *= 2;
        if (percent < 1)
            updateVal =  0.5f * powf(percent, self.easingRate);
        else
            updateVal = sign * 0.5f * (powf(percent - 2 , self.easingRate) + sign*2);
    }

    float value = self.startValue +  (updateVal * (self.endValue - self.startValue));
    // check if counting with ints - cast to int
    if ([self.format rangeOfString:@"%(.*)d" options:NSRegularExpressionSearch].location != NSNotFound ||
       [self.format rangeOfString:@"%(.*)i" options:NSRegularExpressionSearch].location != NSNotFound) {
        self.text = [NSString stringWithFormat:self.format,(int)value];
    } else {
        self.text = [NSString stringWithFormat:self.format,value];
    }
	if (self.progress >= self.duration && self.completionHandler != nil) {
		self.completionHandler(self);
    }
}
@end
