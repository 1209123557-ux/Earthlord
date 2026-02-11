//
//  SupabaseService.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/11.
//

import Foundation
import Supabase

/// 全局 Supabase 客户端实例
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://pxcogttskwqgdwwrarox.supabase.co")!,
    supabaseKey: "sb_publishable_jFn74bbaVjQCc6MVcyRW0w__JskibtA"
)
