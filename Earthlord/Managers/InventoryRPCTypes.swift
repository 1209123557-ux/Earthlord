//
//  InventoryRPCTypes.swift
//  Earthlord
//
//  独立文件：避免与 @MainActor 的 InventoryManager 同文件，
//  防止 Swift 将 Encodable 协议实现推断为 @MainActor 隔离。
//

import Foundation

struct UpsertInventoryParams: Encodable, Sendable {
    let p_user_id:  String
    let p_item_id:  String
    let p_quantity: Int
}
