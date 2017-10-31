# -*- coding: utf-8 -*-
"""Core funyun URLs.
"""
#
# standard library imports
#
import json
from io import StringIO
#
# third-party imports
#
from flask import Response, request, abort, render_template
import arrow
import requests
#
# local imports
#
from . import app
from .rekognizer import Rekognize
#
# Global defs.
#
JSON_MIMETYPE = 'application/json'
TEXT_MIMETYPE = 'text/plain'
JPEG_MIMETYPE = 'image/jpeg'
PNG_MIMETYPE = 'image/png'
REK = Rekognize() # Amazon Rekognition client
JPEG_EXTENSIONS = ['jpg', 'jpeg']
PNG_EXTENSIONS = ['png']
ALLOWED_EXTENSIONS = set(['png', 'jpg', 'jpeg'])
NAME = None
IMAGE = None
#
# Routes (URLS) start here.
#
@app.route('/funyun/time')
def time():
    """A simple return of the time as text.

    :return: Text data
    """
    time_string = 'The time at the server is now %s.'%(arrow.now().format('YYYY-MM-DD HH:mm:ss'))
    return Response(time_string, mimetype=TEXT_MIMETYPE)


@app.route('/funyun/time_as_JSON')
def time_as_JSON():
    """Returns the time as a JSON object.

    :return: JSON data
    """
    json_data = {'time': arrow.now().format('YYYY-MM-DD HH:mm:ss')}
    return Response(json.dumps(json_data), mimetype=JSON_MIMETYPE)


@app.route('/funyun/pass_data', methods=['POST', 'GET'])
def pass_data():
    """Returns data passed as a text object.

    :return: JSON data
    """
    if request.method == 'POST':
        return Response(request.data, mimetype=TEXT_MIMETYPE)
    elif request.method == 'GET':
        return Response('GET of pass_data', mimetype=TEXT_MIMETYPE)


def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def get_image(files):
    # If file wasn't uploaded, it's an error.
    if 'image' not in files:
        app.logger.info('No image uploaded in POST.')
        abort(400)
    file = files['image']
    # if user does not select file, it's an error.
    if file.filename == '':
        app.logger.error('No file selected.')
        abort(400)
    elif not allowed_file(file.filename):
        app.logger.error('Filename %s not allowed' % file.filename)
        abort(403)
    return(file.filename, file.read())


@app.route('/funyun/recognize_as_text', methods=['POST', 'GET'])
def recognize_as_text():
    if request.method == 'POST':
        name, image = get_image(request.files)
        if len(image) > 5*1024*1024:
            app.logger.error('Image size is greater than 5 MB (%d).' %len(image))
            abort(400)
        celebrities = REK.recognize_celebrities(image)
        labels = REK.detect_labels(image)
        faces = REK.detect_faces(image)
        app.logger.info('%s: %d b, %d labels %d faces %d celebs.' %(name,
                                                                    len(image),
                                                                    len(labels),
                                                                    len(faces),
                                                                    len(celebrities)))

        info = REK.all_info()
        outstr = StringIO()
        for key in info.keys():
            outstr.write('%s:  %s\n' %(key,str(info[key])))
        return Response(outstr.getvalue(), mimetype=TEXT_MIMETYPE)
    elif request.method == 'GET':
        return Response('This is a GET', mimetype=TEXT_MIMETYPE)
    else:
        abort(404)

@app.route('/funyun/recognize', methods=['POST', 'GET'])
def recognize():
    global NAME, IMAGE
    templateData = {'version': app.config['VERSION']}
    if request.method == 'POST':
        NAME, IMAGE = get_image(request.files)
        return Response('Upload completed', mimetype=TEXT_MIMETYPE)
    else:
        NAME = None
        IMAGE = None
        return render_template('recognize.html', **templateData)


@app.route('/funyun/lastimage')
def lastimage():
    global NAME,IMAGE
    if IMAGE is None:
        abort(400)
    ext = NAME.rsplit('.', 1)[1].lower()
    if ext in JPEG_EXTENSIONS:
        return Response(IMAGE, mimetype=JPEG_MIMETYPE)
    elif ext in PNG_EXTENSIONS:
        return Response(IMAGE, mimetype=PNG_MIMETYPE)
    else:
        abort(404)


@app.route('/funyun/analyze')
def analyze():
    global IMAGE
    templateData = {'version': app.config['VERSION']}
    if IMAGE is None:
        abort(404)
    if len(IMAGE) > 5*1024*1024:
        app.logger.error('Image size is greater than 5 MB (%d).' %len(IMAGE))
        abort(400)
    celebrities = REK.recognize_celebrities(IMAGE)
    labels = REK.detect_labels(IMAGE)
    faces = REK.detect_faces(IMAGE)
    app.logger.info('%d celebs, %d labels, %d faces' %(len(celebrities),
                                                       len(labels),
                                                       len(faces)))
    templateData['labels'] = labels
    if len(celebrities) > 0:
        celeb = celebrities[0]
        wikiquery = r'https://google.com/search?q="'+\
                    celeb.name + '"&as_sitesearch=wikipedia.org&btnI'
        tophit = requests.get(wikiquery)
        imagequery =  r'https://google.com/search?q="'+\
                    celeb.name + r'"&safe=on&tbm=isch&btnI'
        imghit = requests.get(imagequery)
        templateData['celebrity'] = celeb.__dict__
        if len(celeb.urls) > 0:
            url = 'http://'+ celeb.urls[0]
        else:
            url = tophit.url
        templateData['celebrity']['url'] = url
        templateData['celebrity']['imageurl'] = imghit.url
        app.logger.info('ID = %s', celeb.id)
        if celeb.id  == '4y3xB8v':
            templateData['celebrity']['desc'] = 'Popular Romanian singer'
            templateData['celebrity']['localURL'] = '/static/Carmen_Serban.jpg'
        elif celeb.id == '668PR':
            templateData['celebrity']['desc'] = 'Czech actress'
            templateData['celebrity']['localURL'] = '/static/Barbora_Hrzanova.jpg'
        elif celeb.id == '26o9uJ':
            templateData['celebrity']['desc'] = 'TV mom (Wizards of Waverly Place)'
            templateData['celebrity']['localURL'] = '/static/Maria_Canals-Barrera.jpg'
    else:
        templateData['celebrity'] = None
    if len(faces) > 0:
        face = faces[0]
        templateData['face'] = face
    return render_template('analyze.html', **templateData)