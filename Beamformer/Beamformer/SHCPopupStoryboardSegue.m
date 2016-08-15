#import "SHCPopupStoryboardSegue.h"

static CGFloat kAnimationDuration = 0.33f;



@interface SHCPopupStoryboardSegue ()
@end



@implementation SHCPopupStoryboardSegue

- (void)perform
{
    __block UIViewController *sourceViewController = self.sourceViewController;
    __block UIViewController *destinationViewController = self.destinationViewController;
    UIView *sourceView = sourceViewController.view;
    UIView *destinationView = destinationViewController.view;
    
    if (self.unwind) {
        // On unwind grab our background view, copy it, and add it to the destination view
        UIImageView *backgroundImageView = [[sourceView subviews] objectAtIndex:0];
        [backgroundImageView removeFromSuperview];
        [destinationView addSubview:backgroundImageView];
        
        // Take a snapshot of the remaining view
        UIImage *sourceImage = [self imageWithView:sourceView];
        UIImageView *sourceImageView = [[UIImageView alloc] initWithImage:sourceImage];
        [destinationView addSubview:sourceImageView];
        
        // Remove the view controller without animation and animate our view images
        [destinationViewController dismissViewControllerAnimated:NO completion:nil];
        [UIView animateWithDuration:kAnimationDuration animations:^{
            backgroundImageView.alpha = 0.0f;
            sourceImageView.transform = CGAffineTransformMakeScale(0.001f, 0.001f);
            sourceImageView.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [sourceImageView removeFromSuperview];
            [backgroundImageView removeFromSuperview];
        }];
    } else {
        // Take a snapshot of the source view
        UIImage *sourceImage = [self imageWithView:sourceView];
        UIImageView *sourceImageView = [[UIImageView alloc] initWithImage:sourceImage];
        
        // Add the black backround on top of it.
        UIImage *backgroundImage = [[UIImage imageNamed:@"dialogue-bg.png"] resizableImageWithCapInsets:UIEdgeInsetsZero resizingMode:UIImageResizingModeStretch];
        UIImageView *backgroundImageView = [[UIImageView alloc] initWithImage:backgroundImage];
        backgroundImageView.frame = sourceView.bounds;
        [sourceImageView addSubview:backgroundImageView];
        sourceImageView.alpha = 0.0f;
        [sourceView addSubview:sourceImageView];
        
        // Take a snapshot of the destination view and add it to the source view
        UIImage *destinationImage = [self imageWithView:destinationView];
        UIImageView *destinationImageView = [[UIImageView alloc] initWithImage:destinationImage];
        destinationImageView.alpha = 0.0f;
        destinationImageView.transform = CGAffineTransformMakeScale(0.001f, 0.001f);
        [sourceView addSubview:destinationImageView];
        
        // Begin animation obviously
        [UIView animateWithDuration:kAnimationDuration / 1.5f animations:^{
            destinationImageView.transform = CGAffineTransformMakeScale(1.1f, 1.1f);
            sourceImageView.alpha = 1.0f;
            destinationImageView.alpha = 1.0f;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:kAnimationDuration / 2.0f animations:^(void) {
                destinationImageView.transform = CGAffineTransformMakeScale(0.9f, 0.9f);
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:kAnimationDuration / 2.0f animations:^(void) {
                    destinationImageView.transform = CGAffineTransformIdentity;
                } completion:^(BOOL finished) {
                    // Present the controller without animation to have everything in the correct state
                    [sourceViewController presentViewController:destinationViewController animated:NO completion:nil];
                    // Remove our intermediate animated views from the view hierarchy
                    [destinationImageView removeFromSuperview];
                    [sourceImageView removeFromSuperview];
                    
                    // Stuff the combined source view controller view and black background into the destination view to give the appearance that the view controller is still there.
                    [destinationView insertSubview:sourceImageView atIndex:0];
                }];
            }];
        }];
    }
}

- (UIImage *)imageWithView:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0.0f);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return image;
}

@end
