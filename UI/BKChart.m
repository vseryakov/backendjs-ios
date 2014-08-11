//
//  BKChart.h
//
//  Created by Vlad Seryakov 7/10/14.
//  Copyright (c) 2014. All rights reserved.
//

#import "BKChart.h"

#define chartMargin      4
#define bottomMargin     16
#define fontSize         7
#define DEGREES_TO_RADIANS(degrees) ((M_PI * degrees)/180.0)

@interface BKBar : UIView
@property (nonatomic, strong) CABasicAnimation *anim;
@end

@implementation BKBar {
    float _grade;
    CAShapeLayer *_line;
}
- (id)init:(CGRect)frame color:(UIColor*)color grade:(float)grade
{
    self = [super initWithFrame:frame];
    self.clipsToBounds = YES;
    self.layer.cornerRadius = 2.0;
	_grade = grade;
    
    _line = [CAShapeLayer layer];
    _line.strokeColor = color.CGColor;
    _line.lineCap = kCALineCapButt;
    _line.fillColor = [[UIColor whiteColor] CGColor];
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
    self.anim.duration = 1.0;
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
    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:238.0/255.0 green:238.0/255.0 blue:238.0/255.0 alpha:1.0].CGColor);
	CGContextFillRect(context, rect);
}
@end

@implementation BKBarChart {
    float _xLabelWidth;
    float _chartHeight;
    int _nbars;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.backgroundColor = [UIColor whiteColor];
    self.axisColor = [UIColor blackColor];
    self.barColor = [UIColor greenColor];
    self.barWidth = 10;
    self.clipsToBounds = YES;
    return self;
}

-(void)drawChart
{
    _nbars = 0;
    for (UIView *view in self.subviews) {
        [view removeFromSuperview];
    }
    _chartHeight = self.frame.size.height - chartMargin - bottomMargin;
    int max = 5;
    for (int index = 0; index < _yValues.count; index++) {
        max = MAX(max, [_yValues[index] intValue]);
    }
    _xLabelWidth = (self.frame.size.width - chartMargin*2)/[_xLabels count];
    
    for (int index = 0; index < _xLabels.count; index++) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(index * _xLabelWidth + chartMargin, self.frame.size.height - bottomMargin + 10, _xLabelWidth, bottomMargin)];
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.minimumScaleFactor = fontSize*0.5;
        label.numberOfLines = 0;
        label.font = [UIFont systemFontOfSize:fontSize];
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
		BKBar *bar = [[BKBar alloc] init:CGRectMake(index * _xLabelWidth + chartMargin + _xLabelWidth/2 - self.barWidth/2, self.frame.size.height - _chartHeight - bottomMargin, self.barWidth, _chartHeight) color:color grade:grade];
        bar.anim.delegate = self;
		[self addSubview:bar];
        _nbars++;
    }
}

- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
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
    chartLine.lineWidth = 3.0;
    chartLine.strokeEnd = 0.0;
    chartLine.fillColor = [[UIColor whiteColor] CGColor];
    chartLine.strokeColor = [_lineColor CGColor];
    [self.layer addSublayer:chartLine];
    
    float max = 5, min = INT_MAX;
    for (int i = 0; i < _yValues.count; i++) {
        max = MAX(max, [_yValues[i] floatValue]);
        min = MIN(min, [_yValues[i] floatValue]);
    }
    
    float chartHeight = self.frame.size.height - chartMargin - bottomMargin;
    float yLabelWidth = [[NSString stringWithFormat:@"%0.f", max] length] * fontSize;
    float xLabelWidth = (self.frame.size.width - chartMargin*2 - yLabelWidth)/[_xLabels count];
    float yLabelStep = (max - min) / _yValues.count;
    
    for (int index = 0; index < _xLabels.count; index++) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(chartMargin + yLabelWidth + index * xLabelWidth, self.frame.size.height - bottomMargin - chartMargin + fontSize/2, xLabelWidth, bottomMargin)];
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.minimumScaleFactor = fontSize*0.5;
        label.numberOfLines = 0;
        label.font = [UIFont systemFontOfSize:fontSize];
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = self.axisColor;
        label.text = _xLabels[index];
        [self addSubview:label];
    }
	for (int index = 0; index < 5; index++) {
        float scale = (yLabelStep * index) / (max - min);
        float y = chartHeight - scale * chartHeight;
        // Keep edges within chrating area
        if (scale == 1) y = chartMargin;
        if (scale == 0) y = self.frame.size.height - bottomMargin - fontSize;
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(chartMargin, y, yLabelWidth, bottomMargin)];
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.minimumScaleFactor = fontSize*0.5;
        label.numberOfLines = 0;
        label.font = [UIFont systemFontOfSize:fontSize];
        label.textAlignment = NSTextAlignmentRight;
        label.textColor = self.axisColor;
		label.text = [NSString stringWithFormat:@"%1.f", yLabelStep * index + min];
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
    }
    chartLine.path = progressline.CGPath;
    
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    anim.duration = 1.0;
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

@implementation BKCircleChart {
    CAShapeLayer *_totalLayer;
    CAShapeLayer *_currentLayer;
    CAGradientLayer *_gradientLayer;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.total = 100;
    self.current = 90;
    self.lineWidth = 3;
    self.axisColor = [UIColor blackColor];
    self.currentColor = [UIColor greenColor];
    self.totalColor = [UIColor colorWithRed:90/255. green:198/255. blue:255/255. alpha:1.0];
    self.bgColor = nil;
    
    self.label = [[BKProgressLabel alloc] initWithFrame:self.frame];
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.method = @"EaseOut";
    self.label.format = @"%d%%";
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

    self.label.textColor = self.axisColor;
    self.label.frame = self.frame;
    self.label.center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);

    _totalLayer.path = [UIBezierPath bezierPathWithArcCenter:_label.center
                                                     radius:radius - _lineWidth/2 + 1
                                                 startAngle:DEGREES_TO_RADIANS(0)
                                                   endAngle:DEGREES_TO_RADIANS(360)
                                                  clockwise:NO].CGPath;
    _totalLayer.fillColor = _bgColor.CGColor;
    _totalLayer.strokeColor = _totalColor.CGColor;

    _currentLayer.path = [UIBezierPath bezierPathWithArcCenter:_label.center
                                                        radius:radius
                                                    startAngle:DEGREES_TO_RADIANS(0)
                                                      endAngle:DEGREES_TO_RADIANS(360)
                                                     clockwise:YES].CGPath;
    _currentLayer.strokeColor = _currentColor.CGColor;
    _currentLayer.lineWidth = _lineWidth;
    
    _gradientLayer.frame = self.bounds;
    _gradientLayer.colors = @[ (id)_totalColor.CGColor, (id)_totalColor.CGColor, (id)_currentColor.CGColor, (id)_currentColor.CGColor ];
    
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    anim.duration = 2.0;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    anim.fromValue = [NSNumber numberWithFloat:0.0f];
    anim.toValue = [NSNumber numberWithFloat:_current/_total];
    anim.autoreverses = NO;
    anim.delegate = self;
    [_currentLayer addAnimation:anim forKey:@"strokeEndAnimation"];
    float strokeEnd = _current/_total;
    if (strokeEnd > 1) {
        strokeEnd = 1;
    } else
    if (strokeEnd < 0) {
        strokeEnd = 0;
    }
    _currentLayer.strokeEnd = strokeEnd;
    
    [self.label countFrom:0 to:_currentLayer.strokeEnd*100 duration:anim.duration];
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
    if(self.format == nil) self.format = @"%f";
    
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
    if([self.format rangeOfString:@"%(.*)d" options:NSRegularExpressionSearch].location != NSNotFound ||
       [self.format rangeOfString:@"%(.*)i"].location != NSNotFound) {
        self.text = [NSString stringWithFormat:self.format,(int)value];
    } else {
        self.text = [NSString stringWithFormat:self.format,value];
    }
	if (self.progress == self.duration && self.completionHandler != nil) {
		self.completionHandler(self);
    }
}
@end