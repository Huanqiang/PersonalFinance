//
//  FinanceOfCategoryTableViewCell.swift
//  PersonalFinance
//
//  Created by 子叶 on 16/4/8.
//  Copyright © 2016年 王焕强. All rights reserved.
//

import UIKit

class FinanceOfCategoryTableViewCell: UITableViewCell {

    @IBOutlet weak var categoryIcon: UIImageView!
    @IBOutlet weak var categoryName: UILabel!
    @IBOutlet weak var categoryRatio: UILabel!
    @IBOutlet weak var categoryMoney: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    func prepareCollectionCellForChartView(financeCategory: FinanceOfCategory) {
        self.categoryRatio.text = (financeCategory.categoryRatio * 100).convertToStrWithTwoFractionDigits() + "%"
        self.categoryName.text = financeCategory.categoryName
        self.categoryMoney.text = "￥" + financeCategory.categoryMoney.convertToStrWithTwoFractionDigits()
        self.categoryIcon.image = UIImage(data: financeCategory.iconData!)
    }
    
    func prepareCollectionCellForDayConsumeView(consume: SingleConsume) {
        self.categoryName.text = consume.consumeCategory?.name
        self.categoryMoney.text = "￥" + (consume.money?.doubleValue.convertToStrWithTwoFractionDigits())!
        self.categoryIcon.image = UIImage(data: (consume.consumeCategory?.iconData)!)
    }

}
