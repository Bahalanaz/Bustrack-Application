from functools import wraps
from flask import jsonify
from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity

# FIX: Imported 'Admins' (plural) instead of 'Admin'
from databases_flask_connection import Student, Admins 

def student_required():
    def wrapper(fn):
        @wraps(fn)
        def decorator(*args, **kwargs):
            verify_jwt_in_request()
            current_user_id = get_jwt_identity()
            
            try:
                student = Student.query.get(int(current_user_id))
                if not student:
                    return jsonify({"msg": "Access forbidden: Students only"}), 403
            except (ValueError, TypeError):
                return jsonify({"msg": "Invalid User ID format"}), 422

            return fn(*args, **kwargs)
        return decorator
    return wrapper

def admin_required():
    def wrapper(fn):
        @wraps(fn)
        def decorator(*args, **kwargs):
            verify_jwt_in_request()
            current_user_id = get_jwt_identity()
            
            try:
                # FIX: Used 'Admins' here as well
                admin = Admins.query.get(int(current_user_id))
                if not admin:
                    return jsonify({"msg": "Access forbidden: Admins only"}), 403
            except (ValueError, TypeError):
                return jsonify({"msg": "Invalid User ID format"}), 422

            return fn(*args, **kwargs)
        return decorator
    return wrapper