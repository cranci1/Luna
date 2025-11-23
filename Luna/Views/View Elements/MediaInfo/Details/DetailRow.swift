//
//  DetailRow.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI

struct DetailRow: View {
    let title: String
    let value: String
    let useSolidBackground: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(useSolidBackground ? .primary : .white)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(useSolidBackground ? .primary : .white)
        }
    }
}
