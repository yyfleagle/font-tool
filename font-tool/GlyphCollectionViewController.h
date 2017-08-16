//
//  GlyphCollectionViewController.h
//  tx-research
//
//  Created by Yuqing Jiang on 5/15/17.
//
//

#import <Cocoa/Cocoa.h>
#import "GlyphCollectionViewItem.h"

@class GlyphCollectionViewController;

@protocol GlyphCollectionViewControllerDelegate <NSObject>
@optional
- (void)glyphViewController:(GlyphCollectionViewController*)vc selectGlyphAtIndex:(NSUInteger)index;
@end

@interface GlyphCollectionViewController : NSViewController<NSCollectionViewDataSource, GlyphCollectionViewItemDelegate>

@property (nonatomic, getter=currentBlockIndex, setter=setCurrentBlockIndex:) NSInteger currentBlockIndex;
@property (nonatomic, getter=glyphLabelCategory, setter=setGlyphLabelCategory:) GlyphLabelCategory glyphLabelCategory;

@property (assign) IBOutlet NSObject<GlyphCollectionViewControllerDelegate>* delegate;
@property (assign) IBOutlet NSCollectionView *collectionView;

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView;
- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section;
- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath;

- (void)selectGlyphAtIndex:(NSUInteger)index;

@end
