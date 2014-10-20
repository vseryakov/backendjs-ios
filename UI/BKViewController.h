//
//  BKViewController.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKAnimation.h"
#import "BKRangeSlider.h"
#import "BKMenubarView.h"

// Common view controller
@interface BKViewController: UIViewController

// Name of the current controller
@property (strong, nonatomic) NSString *name;

// How it was brought up: push or set
@property (strong, nonatomic) NSString *navigationMode;

// Who called this controller
@property (strong, nonatomic) NSString *prevControllerName;
@property (strong, nonatomic) NSString *nextControllerName;

// What animation to use during transitions, a dict with properties: type, duration, damping, velocity, options
@property (strong, nonatomic) NSMutableDictionary *transition;

// Return type of the status bar when active
@property (nonatomic, assign) UIStatusBarStyle barStyle;
@property (nonatomic, assign) NSInteger barHeight;

// Parameters passed to the controller
@property (strong, nonatomic) NSMutableDictionary *params;

// Generic collection to be used by table or other view
@property (strong, nonatomic) NSMutableArray *items;

// Original list of items before applying the filter, it is not used by the table but only to keep
// the full list before the search or other condition
@property (strong, nonatomic) NSMutableArray *itemsAll;

// Table support for sections index
@property (strong, nonatomic) NSArray *itemsIndex;
@property (strong, nonatomic) NSArray *itemsIndexTitle;
@property (strong, nonatomic) NSMutableArray *itemsSection;

// Next token for browsing items
@property (strong, nonatomic) NSString *itemsNext;


// Toolbar configuration
@property (nonatomic, assign) NSInteger toolbarHeight;
@property (strong, nonatomic) IBOutlet UIView *toolbarView;
@property (strong, nonatomic) IBOutlet UIButton *toolbarBack;
@property (strong, nonatomic) IBOutlet UILabel *toolbarTitle;
@property (strong, nonatomic) IBOutlet UIButton *toolbarNext;

// Table configuration
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSString *tableCell;
@property (nonatomic, assign) NSInteger tableRows;
@property (nonatomic, assign) BOOL tableTransparent;
@property (nonatomic, assign) BOOL tableShowUnselected;
@property (nonatomic, assign) BOOL tableAutoUnselect;
@property (nonatomic, assign) BOOL tableRestore;

@property (strong, nonatomic) IBOutlet UISearchBar *tableSearchBar;
@property (strong, nonatomic) IBOutlet UITextField *tableSearchField;
@property (strong, nonatomic) NSArray *tableSearchNames;
@property (nonatomic, assign) BOOL tableSearchBarVisible;
@property (nonatomic, assign) BOOL tableSearchable;
@property (nonatomic, assign) BOOL tableSearchHidden;

@property (strong, nonatomic) IBOutlet UIRefreshControl *tableRefresh;
@property (nonatomic, assign) BOOL tableRefreshable;

// Searched value
@property (strong, nonatomic) NSString* searchText;

// To show when no results in the table
@property (strong, nonatomic) UIView *infoView;
@property (strong, nonatomic) UITextView *infoTextView;

// Top menubar view
@property (strong, nonatomic) BKMenubarView *menubarView;

// Bottom tabbar view
@property (strong, nonatomic) BKMenubarView *tabbarView;

// View specific activity indicator
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityView;

// Periodic timer while the controller is visible
@property (nonatomic, assign) int timerInterval;
- (void)onTimer:(NSTimer *)timer;

// Drawer panning gesture
@property (nonatomic, assign) BOOL drawerPanning;
@property (strong, nonatomic) IBOutlet UIButton *drawerView;
@property (nonatomic, strong) UIPanGestureRecognizer *drawerPanGesture;

// (Un)Subscribe to notifications, if the subscribeAlways is YES it will subscribe/unsubscribe once and be kept until deallocated.
@property (nonatomic, assign) BOOL subscribeAlways;
- (void)subscribe;
- (void)unsubscribe;

#pragma mark Navigation

// Return active bk view controller, if the top controller is not derived from BKViewController returns nil
+ (BKViewController*)activeController;

// Called after the view was created but before the view will be shown
- (void)prepareForShow:(UIViewController*)owner name:(NSString*)name mode:(NSString*)mode params:(NSDictionary*)params;

// Called before returning to the previous controller
- (void)prepareForHide:(NSDictionary*)params;

// Called before returning from a child controller
- (void)prepareForReturn;

- (UIViewController*)prevController;
- (void)showPrevious;
- (void)showPrevious:(NSDictionary*)params;

#pragma mark Menubar

- (void)addMenubar:(NSArray*)items params:(NSDictionary*)params;
- (void)updateMenubar:(NSDictionary*)params;

#pragma mark Toolbar

- (void)addToolbar:(NSString*)title params:(NSDictionary*)params;
- (void)onBack:(id)sender;
- (void)onNext:(id)sender;

#pragma mark Tabbar

- (void)addTabbar:(NSArray*)items params:(NSDictionary*)params;

#pragma mark Activity

- (void)showActivity;
- (void)hideActivity;
- (void)showActivity:(BOOL)incr;
- (void)hideActivity:(BOOL)decr;

#pragma mark Table

- (void)addTable;
- (void)reloadTable;
- (void)unselectTable;
- (void)restoreTablePosition;
- (void)saveTablePosition:(NSNumber*)pos;
- (void)hideKeyboard;

- (void)queueTableSearch;
- (void)onTableSearch:(id)sender;

- (void)addInfoView:(NSString*)text;
- (void)addInfoView:(NSString*)text links:(NSArray*)links handler:(SuccessBlock)handler;

#pragma mark Items

- (NSMutableArray*)filterItems:(NSArray*)items;
- (id)getItem:(NSIndexPath*)indexPath;
- (void)setItem:(NSIndexPath*)indexPath data:(id)data;
- (void)getItems;
- (void)clearItems;
- (void)reloadItems:(NSArray*)items;
- (void)refreshItems;
- (void)buildIndex:(NSMutableArray*)list;

#pragma mark Drawer

- (void)showDrawer:(UIViewController*)owner;
- (void)hideDrawer;

#pragma mark Animations

- (BKTransitionAnimation*)getAnimation:(BOOL)present;

#pragma mark Table Cels

- (void)selectTableRow:(int)index animated:(BOOL)animated;
- (void)onTableCell:(UITableViewCell*)cell indexPath:(NSIndexPath*)indexPath;
- (void)onTableSelect:(NSIndexPath *)indexPath selected:(BOOL)selected;
- (UITableViewCellStyle)getTableCellStyle:(NSIndexPath*)indexPath;

#pragma mark TabBar

- (void)onTabBarSelect:(UITabBar*)tabBar item:(UITabBarItem*)item;

#pragma mark Image Pickers

- (void)onImagePicker:(id)picker image:(UIImage*)image params:(NSDictionary*)params;
- (void)showImagePickerFromAlbums:(NSDictionary*)params;
- (void)showImagePickerFromCamera:(id)sender params:(NSDictionary*)params;
- (void)showImagePickerFromLibrary:(id)sender params:(NSDictionary*)params;

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

