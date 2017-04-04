//
//  FaceLib.m
//  FaceLib
//
//  Created by Koji Suzuki on 2017/04/03.
//  Copyright © 2017 Koji Suzuki. All rights reserved.
//

#import "FaceLib.h"
#import <UIKit/UIKit.h>
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#include <dlib/image_processing.h>
#include <dlib/image_io.h>
#include <dlib/opencv/cv_image.h>

using namespace std;

@interface FaceLib ()

@property (assign) BOOL prepared;

+ (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects;
- (NSMutableArray*)extractFaceParts:(dlib::full_object_detection)shape imageMat:(cv::Mat)image;
- (NSMutableArray*)extractFaceAngles:(dlib::full_object_detection)shape imageMat:(cv::Mat)image;

@end

@implementation FaceLib {
    dlib::shape_predictor predictor;
    std::vector<cv::Point3d> model_points;
    BOOL dispPartsFlag;
    BOOL dispAnglesFlag;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _prepared = NO;
        dispPartsFlag = YES;
        dispAnglesFlag = YES;
    }
    return self;
}

- (void)dispPartsFlag:(BOOL)flg {
    dispPartsFlag = flg;
}

- (void)dispAnglesFlag:(BOOL)flg {
    dispAnglesFlag = flg;
}

- (void)prepare {
    
    // dlib initialize
    NSString *modelFileName = [[NSBundle mainBundle] pathForResource:@"shape_predictor_68_face_landmarks" ofType:@"dat"];
    std::string modelFileNameCString = [modelFileName UTF8String];
    dlib::deserialize(modelFileNameCString) >> predictor;
    
    // 3D model points
    model_points.push_back(cv::Point3d(0.0f, 0.0f, 0.0f));               // Nose tip
    model_points.push_back(cv::Point3d(0.0f, -330.0f, -65.0f));          // Chin
    model_points.push_back(cv::Point3d(-225.0f, 170.0f, -135.0f));       // Left eye left corner
    model_points.push_back(cv::Point3d(225.0f, 170.0f, -135.0f));        // Right eye right corner
    model_points.push_back(cv::Point3d(-150.0f, -150.0f, -125.0f));      // Left Mouth corner
    model_points.push_back(cv::Point3d(150.0f, -150.0f, -125.0f));       // Right mouth corner
    
    self.prepared = YES;
}

- (NSArray<NSArray<NSArray<NSValue *> *> *> *)getFeatures:(CMSampleBufferRef)sampleBuffer bounds:(NSArray<NSValue *> *)rects {
    if (!self.prepared) {
        [self prepare];
    }
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    //    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t stride = CVPixelBufferGetBytesPerRow(pixelBuffer);
    size_t width = stride/sizeof(uint32_t);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    uint8_t *baseBuffer = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    cv::Mat image = cv::Mat((int)height, (int)width, CV_8UC4, baseBuffer);
    
    // convert image to dlib image
    dlib::array2d<dlib::bgr_pixel> dlibimage;
    assign_image(dlibimage, dlib::cv_image<dlib::rgb_alpha_pixel>(image));
    
    NSMutableArray *faces = [NSMutableArray array];
    std::vector<dlib::rectangle> convertedRectangles = [FaceLib convertCGRectValueArray:rects];
    for (unsigned long j = 0; j < convertedRectangles.size(); ++j) {
        dlib::full_object_detection shape = predictor(dlibimage, convertedRectangles[j]);
        
        NSMutableArray *face = [NSMutableArray array];
        
        // extract face parts
        NSMutableArray *parts = [self extractFaceParts:shape imageMat:image];
        [face addObject:parts];
        
        // extract face angles
        NSMutableArray *angles = [self extractFaceAngles:shape imageMat:image];
        [face addObject:angles];
        
        [faces addObject:face];
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return faces;
}

+ (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects {
    std::vector<dlib::rectangle> myConvertedRects;
    for (NSValue *rectValue in rects) {
        CGRect rect = [rectValue CGRectValue];
        long left = rect.origin.x;
        long top = rect.origin.y;
        long right = left + rect.size.width;
        long bottom = top + rect.size.height;
        dlib::rectangle dlibRect(left, top, right, bottom);
        
        myConvertedRects.push_back(dlibRect);
    }
    return myConvertedRects;
}

- (NSMutableArray*)extractFaceParts:(dlib::full_object_detection)shape imageMat:(cv::Mat)image {
    NSMutableArray *parts = [NSMutableArray array];
    for (unsigned long k = 0; k < shape.num_parts(); k++) {
        dlib::point p = shape.part(k);
        
        // add face parts
        [parts addObject:[NSValue valueWithCGPoint:CGPointMake(p.x(), p.y())]];
        
        // draw parts
        if(dispPartsFlag) {
            cv::circle(image, cv::Point((int)p.x(), (int)p.y()), 2, cv::Scalar(255, 255, 255, 255), 2, 2);
        }
    }
    return parts;
}

- (NSMutableArray*)extractFaceAngles:(dlib::full_object_detection)shape imageMat:(cv::Mat)image {
    NSMutableArray *angles = [NSMutableArray array];
    
    // 2D image points. If you change the image, you need to change vector
    std::vector<cv::Point2d> image_points;
    image_points.push_back(cv::Point2d(shape.part(30).x(), shape.part(30).y()));  // Nose tip [30]
    image_points.push_back(cv::Point2d(shape.part(8).x(),  shape.part(8).y()));   // Chin [8]
    image_points.push_back(cv::Point2d(shape.part(36).x(), shape.part(36).y()));  // Left eye left corner [36]
    image_points.push_back(cv::Point2d(shape.part(45).x(), shape.part(45).y()));  // Right eye right corner [45]
    image_points.push_back(cv::Point2d(shape.part(48).x(), shape.part(48).y()));  // Left Mouth corner [48]
    image_points.push_back(cv::Point2d(shape.part(54).x(), shape.part(54).y()));  // Right mouth corner [54]
    
    // draw point
    if(dispAnglesFlag) {
        for(int i=0; i<image_points.size(); i++) {
            cv::circle(image, image_points[i] , 5, cv::Scalar(255, 255, 255, 255), 5, cv::LINE_4);
        }
    }
    
    // Camera internals
    double focal_length = image.cols; // Approximate focal length.
    cv::Point2d center = cv::Point2d(image.cols/2, image.rows/2);
    cv::Mat camera_matrix = (cv::Mat_<double>(3,3) << focal_length, 0, center.x, 0 , focal_length, center.y, 0, 0, 1);
    cv::Mat dist_coeffs = cv::Mat::zeros(4,1,cv::DataType<double>::type); // Assuming no lens distortion
    
    cv::Mat rotation_vector; // Rotation in axis-angle form
    cv::Mat translation_vector;
    
    // Solve for pose
    cv::solvePnP(model_points, image_points, camera_matrix, dist_coeffs, rotation_vector, translation_vector);
    
    // draw line
    if(dispAnglesFlag) {
        std::vector<cv::Point3d> nose_end_point3D;
        std::vector<cv::Point2d> nose_end_point2D;
        nose_end_point3D.push_back(cv::Point3d(0,0,1000.0));
        cv::projectPoints(nose_end_point3D, rotation_vector, translation_vector, camera_matrix, dist_coeffs, nose_end_point2D);
        cv::line(image,image_points[0], nose_end_point2D[0], cv::Scalar(5, 5, 255, 255), 4);
    }
    
    // culc angles
    double rot[9] = {0};
    cv::Mat rotation_matrix(3,3,CV_64FC1,rot);
    cv::Rodrigues(rotation_vector, rotation_matrix);
    double* _r = rotation_matrix.ptr<double>();
    double _pm[12] = {_r[0],_r[1],_r[2],0,_r[3],_r[4],_r[5],0,_r[6],_r[7],_r[8],1};
    cv::Mat tmp,tmp1,tmp2,tmp3,tmp4,tmp5;
    cv::Vec3d eav;
    cv::decomposeProjectionMatrix(cv::Mat(3,4,CV_64FC1,_pm),tmp,tmp1,tmp2,tmp3,tmp4,tmp5,eav);
    
    // add angles
    [angles addObject:[NSNumber numberWithDouble:eav[0]]]; // pitch
    [angles addObject:[NSNumber numberWithDouble:eav[1]]]; // yaw
    [angles addObject:[NSNumber numberWithDouble:eav[2]]]; // roll
    
    return angles;
}

@end
