//
//  Transaction.swift
//  Cesium
//
//  Created by Jonathan Foucher on 31/05/2019.
//  Copyright © 2019 Jonathan Foucher. All rights reserved.
//

import Foundation
import CryptoSwift
import Sodium

struct TransactionResponse: Codable {
    var currency: String = "g1"
    var pubkey: String? = nil
    var history: History?
}

struct History: Codable {
    var sent: [Transaction] = []
    var received: [Transaction] = []
    var sending: [Transaction] = []
    var receiving: [Transaction] = []
}

struct Transaction: Codable, Comparable {
    // https://git.duniter.org/nodes/typescript/duniter/issues/1382
    //var version: Int?
    var received: Int? = nil
    var hash: String? = nil
    var currency: String? = nil
    var block_number: Int? = nil
    var time: Int?
    var comment: String? = nil
    var issuers: [String] = []
    var inputs: [String] = []
    var outputs: [String] = []
    var signatures: [String] = []
    var blockstampTime: Int?
    var blockstamp: String?
    
    var locktime: Int = 0
    
    static func < (lhs: Transaction, rhs: Transaction) -> Bool {
        return lhs.time! < rhs.time!
    }
}


struct ParsedTransaction: Comparable {
    var transaction: Transaction
    var amount: Decimal

    var time: Int
    var inputs: [String] = []
    var sources: [String] = []
    var pubKey: String
    var comment: String
    var isUD: Bool = false
    var hash: String
    var locktime: Int = 0
    var block_number: Int?
    var to: [String] = []
    
    static func < (lhs: ParsedTransaction, rhs: ParsedTransaction) -> Bool {
        return lhs.time < rhs.time
    }
    
    init(tx: Transaction, pubKey: String) {
        var walletIsIssuer = false;
        var otherIssuer = tx.issuers.reduce("") {
            (res: String, issuer: String) -> String in
            walletIsIssuer = (issuer == pubKey) ? true : walletIsIssuer;
            return issuer + ((res != pubKey) ? ", " + res : "");
        }
        if (otherIssuer.count > 0) {
            otherIssuer = String(otherIssuer.dropLast(2));
        }
        
        self.transaction = tx
        var otherReceiver: String = ""
        self.amount = 0
        self.time = 0
        self.pubKey = ""
        self.comment = tx.comment!
        self.hash = tx.hash!
        self.locktime = tx.locktime
        self.block_number = tx.block_number
        
        
        let total = tx.outputs.reduce(0) {
            (sum: Decimal, output: String) -> Decimal in
            let outputArray = output.components(separatedBy: ":")

            let outputBase = Int(outputArray[1])!
            let outputAmount = powBase(amount: Decimal(Int(outputArray[0])!), base: outputBase)

            let outputCondition = outputArray[2]
            let pattern = "SIG\\(([0-9a-zA-Z]+)\\)"

            var sigMatches:[String] = []
            
            let res = self.matchAll(string: outputCondition, pattern: pattern)
            
            if (res.count > 0) {
                sigMatches = res[0]
            }
            
            if ( sigMatches.count > 1) {
                let outputPubkey = sigMatches[1];
                
                if (outputPubkey == pubKey) { // output is for the wallet
                    if (!walletIsIssuer) {
                        return sum + outputAmount;
                    }
                }
                else { // output is for someone else
                    if (outputPubkey != "" && outputPubkey != otherIssuer) {
                        otherReceiver = outputPubkey;
                    }
                    if (walletIsIssuer) {
                        return sum - outputAmount;
                    }
                }
            
            } else if (outputCondition.contains("SIG("+pubKey+")")) {
                print("TODOTODO")
//                var lockedOutput = BMA.tx.parseUnlockCondition(outputCondition);
//                if (lockedOutput) {
//
//                    lockedOutput.amount = outputAmount;
//                    lockedOutputs = lockedOutputs || [];
//                    lockedOutputs.push(lockedOutput);
//                    console.debug('[tx] has locked output:', lockedOutput);
//
//                    return sum + outputAmount;
//                }
            }
            return sum
        }
    
        self.to = tx.outputs.map { out -> String in
            let outputArray = out.components(separatedBy: ":")
            let pattern = "SIG\\(([0-9a-zA-Z]+)\\)"
            let res = self.matchAll(string: outputArray[2], pattern: pattern)
            
            if (res.count > 0) {
                let matches = res[0]
                if (matches.count > 1) {
                    return matches[1]
                }
            }
            return ""
            }.filter { $0 == pubKey }
//            .filter { out in
//            return !out.contains("SIG("+pubKey+")")
//        }

        
        let txPubkey = total > 0 ? otherIssuer : otherReceiver;

        
        let time = tx.time != nil ? tx.time : tx.blockstampTime;
        self.time = time!
        self.amount = total
        self.pubKey = txPubkey
        self.comment = tx.comment!
        self.isUD = false
        
        

        // If pending: store sources and inputs for a later use - see method processTransactionsAndSources()
        if (walletIsIssuer && tx.block_number == nil) {
            self.inputs = tx.inputs;
        }
        
//        if (lockedOutputs) {
//            newTx.lockedOutputs = lockedOutputs;
//        }
    }
    
    func powBase(amount: Decimal, base: Int) -> Decimal {
        return base <= 0 ? amount : amount * pow(10, base);
    }
    
    func matchAll(string: String, pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let range = NSRange(location: 0, length: string.utf16.count)
        let m = regex.matches(in: string, options: [], range: range)
        
        return  m.map { match in
            return (0..<match.numberOfRanges).map { (a) -> String in
                let rangeBounds = match.range(at: a)
                guard let range = Range(rangeBounds, in: string) else {
                    return ""
                }
                return String(string[range])
            }
        }
    }
}



