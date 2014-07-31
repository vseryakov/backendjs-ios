//
//  BKViewController.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKAnimation.h"
#import "BKRangeSlider.h"

// Common view controller
@interface BKViewController: UIViewController

// Name of the current controller
@property (strong, nonatomic) NSString *name;

// How it was brought up: push or set
@property (strong, nonatomic) NSString *navigationMode;

// Who called this controller
@property (strong, nonatomic) NSString *previousName;

// What animation to use during transitions
@property (strong, nonatomic) NSString *transitionType;
@property (nonatomic) float transitionDuration;
@property (nonatomic) float transitionDamping;
@property (nonatomic) float transitionVelocity;
@property (nonatomic) UIViewAnimationOptions transitionOptions;

// Return type of the status bar when active
@property (nonatomic, assign) UIStatusBarStyle barStyle;

// Parameters passed to the controller
@property (strong, nonatomic) NSMutableDictionary *params;

// Generic collection to be used by table or other view
@property (strong, nonatomic) NSMutableArray *items;

// Original list of items before applying the filter, it is not used by the table but only to keep
// the full list before the search or other condition
@property (strong, nonatomic) NSMutableArray *itemsAll;

// Toolbar configuration
@property (strong, nonatomic) IBOutlet UIView *toolbarView;
@property (strong, nonatomic) IBOutlet UIButton *toolbarBack;
@property (strong, nonatomic) IBOutlet NSString *toolbarBackIcon;
@property (strong, nonatomic) IBOutlet NSString *toolbarBackTitle;
@property (strong, nonatomic) IBOutlet UILabel *toolbarTitle;
@property (strong, nonatomic) IBOutlet UIButton *toolbarNext;
@property (strong, nonatomic) IBOutlet NSString *toolbarNextIcon;
@property (strong, nonatomic) IBOutlet NSString *toolbarNextTitle;
@property (strong, nonatomic) IBOutlet NSString *toolbarNextController;
@property (nonatomic, assign) NSInteger toolbarOffset;

// Table configuration
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSString *tableCell;
@property (nonatomic, assign) NSInteger tableRows;
@property (nonatomic, assign) NSInteger tableSections;
@property (nonatomic, assign) BOOL tableUnselected;
@property (nonatomic, assign) BOOL tableRounded;
@property (nonatomic, assign) BOOL tableRestore;

@property (strong, nonatomic) IBOutlet UISearchBar *tableSearch;
@property (strong, nonatomic) NSArray *tableSearchNames;
@property (nonatomic, assign) BOOL tableSearchable;
@property (nonatomic, assign) BOOL tableSearchHidden;

@property (strong, nonatomic) IBOutlet UIRefreshControl *tableRefresh;
@property (nonatomic, assign) BOOL tableRefreshable;

// Searched value
@property (strong, nonatomic) NSString* searchText;

// To show when no results in the table
@property (strong, nonatomic) UIView *emptyView;
@property (strong, nonatomic) UITextView *emptyTextView;

// Top menubar view
@property (strong, nonatomic) NSMutableArray *menubarItems;
@property (strong, nonatomic) IBOutlet UIView *menubarView;
@property (strong, nonatomic) NSMutableDictionary *menubarButtons;

// View specific activity indicator
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityView;

// Drawer panning gesture
@property (nonatomic, assign) BOOL drawerPanning;
@property (strong, nonatomic) IBOutlet UIButton *drawerView;
@property (nonatomic, strong) UIPanGestureRecognizer *drawerPanGesture;

// Push mode panning gesture
@property (nonatomic, assign) CGRect panRect;
@property (nonatomic, assign) BOOL panInPushMode;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;

// Subscribe to notifications
- (void)subscribe;

#pragma mark Navigation

// Called after the view was created but before the view will be shown
- (void)prepareForShow:(UIViewController*)owner name:(NSString*)name mode:(NSString*)mode params:(NSDictionary*)params;

- (UIViewController*)prevController;
- (void)showPrevious;
- (void)showPrevious:(NSDictionary*)params;

#pragma mark Menubar

- (void)addMenubar:(NSArray*)items params:(NSDictionary*)params;
- (void)setMenubarButton:(NSString*)name enabled:(BOOL)enabled;

#pragma mark Toolbar

- (void)addToolbar:(NSString*)title;
- (void)setToolbarBackButton:(NSString*)title image:(UIImage*)image;
- (void)setToolbarNextButton:(NSString*)title image:(UIImage*)image;
- (void)onBack:(id)sender;
- (void)onNext:(id)sender;

#pragma mark Activity

- (void)showActivity;
- (void)hideActivity;
- (void)showActivity:(BOOL)incr;
- (void)hideActivity:(BOOL)decr;

#pragma mark Table

- (void)addTable;
- (void)reloadTable;
- (void)restoreTablePosition;
- (void)saveTablePosition:(NSNumber*)pos;
- (void)hideKeyboard;

- (void)queueTableSearch;
- (void)onTableSearch:(id)sender;

- (void)addEmptyView:(NSString*)text;
- (void)addEmptyView:(NSString*)text links:(NSArray*)links handler:(SuccessBlock)handler;

#pragma mark Items

- (NSMutableArray*)filterItems:(NSArray*)items;
- (id)getItem:(NSIndexPath*)indexPath;
- (void)setItem:(NSIndexPath*)indexPath data:(id)data;
- (void)getItems;
- (void)refreshItems;

#pragma mark Drawer

- (void)showDrawer:(UIViewController*)owner;
- (void)hideDrawer;

#pragma marj Animations

- (BKTransitionAnimation*)getAnimation:(BOOL)present;

#pragma mark Table Cels

- (void)selectTableRow:(int)index animated:(BOOL)animated;
- (void)onTableCell:(UITableViewCell*)cell indexPath:(NSIndexPath*)indexPath;
- (void)onTableSelect:(NSIndexPath *)indexPath selected:(BOOL)selected;
- (UITableViewCellStyle)getTableCellStyle:(NSIndexPath*)indexPath;

#pragma mark TabBar

- (void)onTabBarSelect:(UITabBar*)tabBar item:(UITabBarItem*)item;

#pragma mark Image Pickers

- (void)onImagePicker:(UIImage*)image params:(NSDictionary*)params;
- (void)showImagePickerFromAlbums:(NSDictionary*)params;
- (void)showImagePickerFromCamera:(id)sender params:(NSDictionary*)params;
- (void)showImagePickerFromLibrary:(id)sender params:(NSDictionary*)params;

#pragma mark Gestures

- (BOOL)onGesture:(UIGestureRecognizer *)recognizer touch:(UITouch *)touch;

@end

#pragma mark UIView Frame shortcuts

@interface UIView (Frame)
@property (nonatomic, assign) CGFloat x;
@property (nonatomic, assign) CGFloat y;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGPoint origin;
@property (nonatomic, assign) CGFloat right;
@property (nonatomic, assign) CGFloat bottom;
@property (nonatomic, assign) CGFloat centerX;
@property (nonatomic, assign) CGFloat centerY;
@property (nonatomic, assign) CGSize size;
@end

