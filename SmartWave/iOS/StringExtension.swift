import Foundation
import UIKit
import CoreGraphics



extension String {
    func rect(withFont font: UIFont) -> CGRect
    {
        let constraintRect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        return self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSFontAttributeName: font], context: nil)
    }
    
    func width(withFont font: UIFont) -> CGFloat
    {
        return ceil(self.rect(withFont: font).width)
    }
    
    func height(withFont font: UIFont) -> CGFloat
    {
        return ceil(self.rect(withFont: font).height)
    }
}

