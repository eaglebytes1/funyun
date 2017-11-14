#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Standard library imports.
#
from collections import OrderedDict
from io import StringIO
#
# Third-party imports.
#
import boto3
#
# Global defs.
#
FEATURES_BLACKLIST = ('Landmarks',
                      'Emotions',
                      'Pose',
                      'Quality',
                      'BoundingBox',
                      'Confidence')
#
# Class definitions.
#
class Rekognize(object):
    """Use Amazon Rekognize for image operations
    """
    class Face(object):
        """Data for each face recognized
        """
        class Age(object):
            def __init__(self, low, high):
                self.low = low
                self.high = high

            def __str__(self):
                return 'between %d and %d years' %(self.low, self.high)


        class Feature(object):
            def __init__(self, name, value, confidence):
                self.name = name
                self.value = value
                self.confidence = confidence


            def __str__(self):
                return ' %s: %s (%.0f%%)' %(self.name,
                                              self.value,
                                              self.confidence)


        def __init__(self):
            self.emotions = OrderedDict()
            self.age = self.Age(0, 100)
            self.features = []
            self.confidence = 0


        def __str__(self, noFalse=True):
            outstr = StringIO()
            outstr.write('   Confidence this is a face: %.0f%%\n' %self.confidence)
            outstr.write('   Age: %s\n' %self.age)
            outstr.write('   Emotions:\n')
            for emotion in self.emotions:
                outstr.write('      %s: (%.0f%%)\n'
                             %(emotion, self.emotions[emotion])
                             )
            outstr.write('   Features:\n')
            for feature in self.features:
                if noFalse and not feature.value:
                    continue
                outstr.write('      %s: %s (%.0f%%)\n'
                             %(feature.name,
                               feature.value,
                               feature.confidence))
            return outstr.getvalue()


    class Celebrity(object):
        def __init__(self, name, ident, confidence, urls):
            self.name = name
            self.urls = urls
            self.id = ident
            self.confidence = confidence


        def __str__(self):
            outstr = StringIO()
            outstr.write('   %s (%.0f%%)\n' %(self.name, self.confidence))
            outstr.write('      %d URLs for %s:\n' %(len(self.urls),
                                                     self.name))
            for url in self.urls:
                outstr.write('       http://%s\n' %url)
            return outstr.getvalue()


    def __init__(self, region='us-west-2'):
        self.client = boto3.client('rekognition', region)
        self.labels = None
        self.faces = None
        self.celebrities = None


    def all_info(self):
        return_dict = {}
        if self.celebrities is not None and len(self.celebrities) >0:
            return_dict['celebrities'] = self.celebrities
        if self.labels is not None and len(self.labels) >0:
            return_dict['labels'] = self.labels
        if self.faces is not None and len(self.faces) >0:
            return_dict['faces'] = self.faces
        return return_dict


    def detect_labels(self,
                      img,
                      max_labels=100,
                      min_confidence=50,
                      verbose=False):
        if verbose:
            print('Detecting labels...')
        self.labels = OrderedDict()
        response = self.client.detect_labels(Image={'Bytes': img},
                                             MaxLabels=max_labels,
                                             MinConfidence=min_confidence)
        label_list = response['Labels']
        if verbose:
            print('   %d features recognized in image:' % len(label_list))
        for label_num, label in enumerate(label_list):
            name = label['Name']
            confidence = label['Confidence']
            self.labels[name] = confidence
        return self.labels


    def recognize_celebrities(self, img, verbose=False):
        if verbose:
            print('Recognizing celebrities...')
        self.celebrities = []
        response = self.client.recognize_celebrities(Image={'Bytes': img})
        celebrities = response['CelebrityFaces']
        for celebrity in celebrities:
            name = celebrity['Name']
            urls = celebrity['Urls']
            ident = celebrity['Id']
            confidence = celebrity['MatchConfidence']
            self.celebrities.append(self.Celebrity(name,
                                                   ident,
                                                   confidence,
                                                   urls ))
        if verbose:
            print('  %d celebrities recognized.' %len(celebrities))
        return self.celebrities


    def print_labels(self):
        for label_num, label in enumerate(self.labels):
            print('      %d. %s (%.0f%%)' % (label_num,
                                             label,
                                             self.labels[label]))


    def detect_faces(self, img, attributes=['ALL'], verbose=False):
        if verbose:
            print('Analyzing faces...')
        self.faces = []
        response = self.client.detect_faces(Image={'Bytes': img},
                                            Attributes=attributes)
        facedata = response['FaceDetails']
        newface = self.Face()
        for face in facedata:
            newface.confidence = face['Confidence']
            for emotion in face['Emotions']:
                name = emotion['Type'].capitalize()
                confidence = emotion['Confidence']
                newface.emotions[name] = confidence
            for feature in [f for f in face.keys()
                            if f not in FEATURES_BLACKLIST]:
                vals = face[feature]
                if feature == 'AgeRange':
                    newface.age.low = vals['Low']
                    newface.age.high = vals['High']
                else:
                    newface.features.append(self.Face.Feature(feature,
                                                              vals['Value'],
                                                              vals['Confidence'])
                                            )
            self.faces.append(newface)
        return self.faces


if __name__ == '__main__':
    import os
    import sys
    EXTS = ['.jpg', '.jpeg', '.png']
    #
    # Validate inputs.
    #
    if len(sys.argv) != 2:
        print('ERROR--Must specify a filename.')
        sys.exit(1)
    filename = sys.argv[1]
    root, ext = os.path.splitext(filename)
    if ext.lower() not in EXTS:
        print('ERROR--File extension must be one of %s.' %EXTS)
        sys.exit(1)
    try:
        filesize = os.path.getsize(filename)
    except OSError:
        print('ERROR--file "%s" does not exist.' %filename)
    if filesize > 5*1024*1024:
        print('ERROR--File size (%.0f MB) greater than 5 MB limit.'
              %filesize/1024./1024.)
    #
    # Do Rekognize functions.
    #
    rek = Rekognize()
    with open(filename, 'rb') as image_fh:
        image = image_fh.read()

    labels = rek.detect_labels(image, verbose=True)
    rek.print_labels()
    faces = rek.detect_faces(image, verbose=True)
    for face_num, face in enumerate(faces):
        print('Face %d:' %(face_num))
        print('%s' %face)
    celebrities = rek.recognize_celebrities(image, verbose=True)
    for celebrity in celebrities:
        print('   %s' %celebrity)


