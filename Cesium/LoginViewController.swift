//
//  LoginViewController.swift
//  Cesium
//
//  Created by Jonathan Foucher on 30/05/2019.
//  Copyright © 2019 Jonathan Foucher. All rights reserved.
//

import Foundation
import UIKit
import Sodium
import CryptoSwift

enum PublicKeyError: Error {
    case emptyFields
    case couldNotCalculate
}

struct KeyPair {
    var publicKey: Bytes
    var secretKey: Bytes
}

class LoginViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var secret: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var publicKey: UILabel!
    @IBOutlet weak var keyImage: UIImageView!
    @IBOutlet weak var topbarHeight: NSLayoutConstraint!
    @IBOutlet weak var topBar: UIView!
    
    weak var loginDelegate: LoginDelegate?
    weak var loginFailedDelegate: LoginFailedDelegate?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        self.keyImage.image = nil
        self.publicKey.text = ""
        
        if let navigationController = UIApplication.shared.keyWindow?.rootViewController as? UINavigationController {
            print("found")
            self.topbarHeight.constant = navigationController.navigationBar.frame.height
            self.view.layoutIfNeeded()
        }
        
        if let p = self.parent {
            let name = NSStringFromClass(type(of: p))
            if (name == "Cesium.FirstViewController") {
                self.topBar.removeFromSuperview()
            }
        }

        
    }
    
    @IBAction func close(_ sender: Any) {
        self.dismiss(animated: true
            , completion: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0 /*&& UIScreen.main.bounds.height - 420 < keyboardSize.height*/ {
                var val = CGFloat(100.0)
                if let frame = self.loginButton?.frame {
                    val = CGFloat(UIScreen.main.bounds.height - frame.origin.y) - frame.height - 10
                }
                self.view.frame.origin.y -= CGFloat(keyboardSize.height) - val
                
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
    

    
    override func viewWillAppear(_ animated: Bool) {
        let image = UIImage(named: "logo")
        let imageView = UIImageView(image: image!)
        imageView.frame = CGRect(x: 0, y: 100, width: 150, height: 150)
        imageView.center.x = self.view.center.x
        //self.view.addSubview(imageView)
        let backItem = UIBarButtonItem()
        backItem.title = "logout_button_label".localized()
        backItem.tintColor = .white
        self.navigationItem.backBarButtonItem = backItem
        
        
        
        self.secret.borderStyle = UITextField.BorderStyle.roundedRect
        self.secret.placeholder = "identifier_placeholder".localized()
        self.secret.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center

        self.secret.addTarget(self, action: #selector(fieldEditingChanged), for: UIControl.Event.editingChanged)
        
        self.password.borderStyle = UITextField.BorderStyle.roundedRect
        self.password.placeholder = "password_placeholder".localized()
        self.password.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        
        self.password.addTarget(self, action: #selector(fieldEditingChanged), for: UIControl.Event.editingChanged)
        //sampleTextField.delegate = self
        //self.view.addSubview(self.secret)
        //self.view.addSubview(self.password)

        self.loginButton.setTitle("login_button_label".localized(), for: .normal)
        self.loginButton.layer.cornerRadius = 6
        self.loginButton.addTarget(self, action: #selector(buttonAction), for: UIControl.Event.touchUpInside)
        
        //self.view.addSubview(button)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.secret {
            textField.resignFirstResponder()
            self.password.becomeFirstResponder()
        } else if textField == self.password {
            textField.resignFirstResponder()
            self.buttonAction()
        }
        return true
    }
    
    @objc func fieldEditingChanged(_ sender: Any) {
        do {
            let pk = try self.calculatePublicKey()
            self.publicKey.text = pk
            self.keyImage.image = UIImage(named:"key")
        } catch {
            self.error(message: "could not calculate public key", code: 0)
            self.keyImage.image = nil
            self.publicKey.text = ""
        }
    }
    
    func calculatePublicKey() throws -> String {
        let id: String = self.secret.text!
        let pass: String = self.password.text!
        
        let password: Array<UInt8> = Array(pass.utf8)
        let salt: Array<UInt8> = Array(id.utf8)
        guard let seed = try? Scrypt(password: password, salt: salt, dkLen: 32, N: 4096, r: 16, p: 1).calculate() else {
           throw PublicKeyError.couldNotCalculate
        }
        let sodium = Sodium()
        let k = sodium.sign.keyPair(seed: seed)
        if let key = k {
            let encoded = Base58.base58FromBytes(key.publicKey)
            return encoded
        }
        throw PublicKeyError.couldNotCalculate
    }
    
    func calculateKeyPair(id: String, pass: String) throws -> KeyPair {
        let password: Array<UInt8> = Array(pass.utf8)
        let salt: Array<UInt8> = Array(id.utf8)
        guard let seed = try? Scrypt(password: password, salt: salt, dkLen: 32, N: 4096, r: 16, p: 1).calculate() else {
            throw PublicKeyError.couldNotCalculate
        }
        let sodium = Sodium()
        let k = sodium.sign.keyPair(seed: seed)
        if let key = k {
            return KeyPair(publicKey: key.publicKey, secretKey: key.secretKey)
        }
        throw PublicKeyError.couldNotCalculate
    }
    
    @IBAction func buttonAction() {
        let id: String = self.secret.text!
        let pass: String = self.password.text!
        // We have the public key, make a request
        guard let pubK = try? self.calculatePublicKey() else {
            return
        }
        
        Profile.getRequirements(publicKey: pubK, callback: { identity in
            if (identity == nil) {
                self.error(message: "no identity", code: 12)
            }
            
            Profile.getProfile(publicKey: pubK, identity: identity, callback: { profile in
                if var prof = profile {
                    // Keep the secret key in memory for the duration of the session
                    if let kp = try? self.calculateKeyPair(id: id, pass: pass) {
                        prof.kp = Base58.base58FromBytes(kp.secretKey)
                    }
                    self.loginDelegate?.login(profile: prof)
                }
                DispatchQueue.main.async {
                    self.password.text = ""
                    self.secret.text = ""
                    self.publicKey.text = ""
                    self.keyImage.image = nil
                }
            })
        })
        // TODO this checks if the user is in the API, but they could be only on the nodes
        // Should we let them in even if the api is not aware ?
        // https://g1.nordstrom.duniter.org/wot/requirements/9itUPU7CVJEHh5DszAYQvgdUvTDLUNkY6NngMfo3F18k
        
    }
    
    
    func error(message: String, code: Int) {
        if (code == 12) {
            self.loginFailedDelegate?.loginFailed(error: message)
        }
    }
    
    
    
}
