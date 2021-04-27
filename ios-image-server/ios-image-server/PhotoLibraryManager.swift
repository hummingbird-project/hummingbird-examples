//
//  PhotoLibraryManager.swift
//  ios-image-server
//
//  Created by Adam Fowler on 26/04/2021.
//

import Hummingbird
import NIO
import Photos
import UIKit

class PhotoLibraryManager {
    enum Error: Swift.Error {
        case noPhotos
        case invalidIndex
        case loadFailed
    }

    init(eventLoop: EventLoop) {
        self.photosPromise = eventLoop.makePromise()
        fetchLibrary()
    }

    func requestAuthorization(_ authorized: @escaping ()->(), denied: @escaping ()->() = {}) {
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

    func fetchLibrary() {
        requestAuthorization {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending:false)]
            self.photosPromise.succeed(PHAsset.fetchAssets(with: fetchOptions))
        }
    }

    func loadPhoto(index: Int, targetSize: CGSize = CGSize(width: 1024, height: 1024), _ cb: @escaping (Result<Data, Swift.Error>) -> ()) {
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

            manager.requestImage(for: photo, targetSize: targetSize, contentMode: .aspectFit, options: option, resultHandler: { result, info in
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
