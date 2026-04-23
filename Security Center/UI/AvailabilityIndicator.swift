//
//  AvailabilityIndicator.swift
//  Security Center
//
//  Created by George Babichev on 1/9/26.
//

import SwiftUI

struct AvailabilityIndicator: View {
    let isAvailable: Bool

    var body: some View {
        Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle")
            .foregroundStyle(isAvailable ? .green : .secondary)
    }
}
