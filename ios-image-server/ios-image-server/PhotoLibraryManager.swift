//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import NIO
import Photos
import UIKit

/// Loads photos from the iOS photo library
class PhotoLibraryManager {
    enum Error: Swift.Error {
        case noPhotos
        case invalidIndex
        case loadFailed
    }

    init(eventLoop: EventLoop) {
        self.photosPromise = eventLoop.makePromise()
        self.fetchLibrary()
    }

    func requestAuthorization(_ authorized: @escaping () -> Void, denied: @escaping () -> Void = {}) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            switch status {
            case .authorized:
                authorized()
            case .denied, .limited:
                denied()
            case .notDetermined:
                break
            default:
                break
            }
        }
    }

    /// fetch contents of photo library
    func fetchLibrary() {
        self.requestAuthorization {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            self.photosPromise.succeed(PHAsset.fetchAssets(with: fetchOptions))
        }
    }

    /// Load photo and create Jpeg from image
    /// - Parameters:
    ///   - index: Index of image
    ///   - targetSize: target size of image
    ///   - cb: Callback to call when image is ready
    func loadPhoto(index: Int, targetSize: CGSize = CGSize(width: 1024, height: 1024), _ cb: @escaping (Result<Data, Swift.Error>) -> Void) {
        self.photosPromise.futureResult.whenSuccess { photos in
            guard index < photos.count else {
                cb(.failure(Error.invalidIndex))
                return
            }
            let photo = photos[index]
            let manager = PHImageManager.default()
            let option = PHImageRequestOptions()
            option.isSynchronous = false
            option.resizeMode = .exact
            option.deliveryMode = .highQualityFormat

            manager.requestImage(for: photo, targetSize: targetSize, contentMode: .aspectFit, options: option, resultHandler: { result, _ in
                guard let image = result else {
                    cb(.failure(Error.loadFailed))
                    return
                }
                // convert to JPEG
                guard let data = image.jpegData(compressionQuality: 0.9) else {
                    cb(.failure(Error.loadFailed))
                    return
                }
                cb(.success(data))
            })
        }
    }

    var photosPromise: EventLoopPromise<PHFetchResult<PHAsset>>
}
