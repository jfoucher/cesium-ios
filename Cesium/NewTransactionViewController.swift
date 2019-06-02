//
//  NewTransactionViewController.swift
//  Cesium
//
//  Created by Jonathan Foucher on 01/06/2019.
//  Copyright © 2019 Jonathan Foucher. All rights reserved.
//

import Foundation
import UIKit


class NewTransactionViewController: UIViewController, UITextViewDelegate {
    var receiver: Profile?
    var sender: Profile?
    var currency: String?

    @IBOutlet weak var senderAvatar: UIImageView!
    @IBOutlet weak var receiverAvatar: UIImageView!
    @IBOutlet weak var arrow: UIImageView!

    @IBOutlet weak var senderBalance: UILabel!
    @IBOutlet weak var receiverName: UILabel!
    @IBOutlet weak var senderName: UILabel!
    @IBOutlet weak var receiverPubKey: UILabel!
    @IBOutlet weak var senderPubKey: UILabel!
    @IBOutlet weak var amount: UITextField!
    @IBOutlet weak var comment: UITextView!
    @IBOutlet weak var cancelButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set arrow to white
        self.arrow.tintColor = .white
        self.arrow.image = UIImage(named: "arrow-right")?.withRenderingMode(.alwaysTemplate)
        
        self.amount.addDoneButtonToKeyboard(myAction:  #selector(self.amount.resignFirstResponder))
        self.comment.addDoneButtonToKeyboard(myAction:  #selector(self.comment.resignFirstResponder))
        
        self.comment.text = "comment_placeholder".localized()
        self.comment.textColor = .lightGray
        
        if let receiver = self.receiver {
            self.receiverAvatar.layer.borderWidth = 1
            self.receiverAvatar.layer.masksToBounds = false
            self.receiverAvatar.layer.borderColor = UIColor.white.cgColor
            self.receiverAvatar.layer.cornerRadius = self.receiverAvatar.frame.width/2
            self.receiverAvatar.clipsToBounds = true

            receiver.getAvatar(imageView: self.receiverAvatar)

            self.receiverName.text = receiver.title != nil ? receiver.title : receiver.uid
        }
        
        
        if let sender = self.sender {
            self.senderAvatar.layer.borderWidth = 1
            self.senderAvatar.layer.masksToBounds = false
            self.senderAvatar.layer.borderColor = UIColor.white.cgColor
            self.senderAvatar.layer.cornerRadius = self.receiverAvatar.frame.width/2
            self.senderAvatar.clipsToBounds = true
            
            sender.getAvatar(imageView: self.senderAvatar)
            
            self.senderName.text = sender.title != nil ? sender.title : sender.uid
            
            sender.getBalance(callback: { str in
                DispatchQueue.main.async {
                    self.senderBalance.text = str
                }
            })
        }
        
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        //move view up a bit
        print(UIScreen.main.bounds.height)
        if (UIScreen.main.bounds.height < 700) {
            UIView.animate(withDuration: 0.3, animations: {
                self.view.frame.origin.y -= 100
            })
        }
        if (textView.text == "comment_placeholder".localized() && textView.textColor == .lightGray)
        {
            textView.text = ""
            textView.textColor = .black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        //move view down
        if (UIScreen.main.bounds.height < 700) {
            UIView.animate(withDuration: 0.2, animations: {
                self.view.frame.origin.y = 0
            })
        }
        if (textView.text == "")
        {
            textView.text = "comment_placeholder".localized()
            textView.textColor = .lightGray
        }
    }
    
    @IBAction func cancel(sender: UIButton) {
        print("cancel")
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func send(sender: UIButton) {
        
        guard let title = self.receiver?.title else { return  }
        guard let currency = self.currency else { return  }
        guard let amstring = self.amount.text else { return  }
        print(amstring)
        let am = Float(amstring) ?? 0
        print(am)
        let amountString = String(format: "%.2f %@", am, Currency.formattedCurrency(currency: currency))
        
        let msg = String(format: "transaction_confirm_message".localized(), amountString, title)
        let alert = UIAlertController(title: "transaction_confirm_prompt".localized(), message: msg, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "transaction_confirm_button_label".localized(), style: .default, handler: {ac in
            print("send")
            
        }))
        
        alert.addAction(UIAlertAction(title: "transaction_cancel_button_label".localized(), style: .cancel, handler: nil))
        
        self.present(alert, animated: true)
    }
    
    @IBAction func changeReceiver(sender: UIButton) {
        print("change")
    }
    
    
}