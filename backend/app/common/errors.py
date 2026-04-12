from flask import jsonify


def success_response(data=None, message=None, status_code=200):
    body = {'success': True}
    if message:
        body['message'] = message
    if data is not None:
        body['data'] = data
    return jsonify(body), status_code


def error_response(message, status_code=400, errors=None):
    body = {'success': False, 'message': message}
    if errors:
        body['errors'] = errors
    return jsonify(body), status_code


def paginated_response(items, total, page, per_page):
    return jsonify({
        'success': True,
        'data': items,
        'pagination': {
            'total': total,
            'page': page,
            'per_page': per_page,
            'pages': (total + per_page - 1) // per_page,
        }
    })
