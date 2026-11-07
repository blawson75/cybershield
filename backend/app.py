from flask import Flask, jsonify, request
from flask_cors import CORS
import random
from datetime import datetime

app = Flask(__name__)
CORS(app)

DATA_BROKERS = [
    {"id": 1, "name": "Spokeo", "category": "People Search", "risk_level": "High"},
    {"id": 2, "name": "Whitepages", "category": "People Search", "risk_level": "High"},
    {"id": 3, "name": "Intelius", "category": "People Search", "risk_level": "Medium"},
    {"id": 4, "name": "BeenVerified", "category": "People Search", "risk_level": "High"},
    {"id": 5, "name": "TruthFinder", "category": "People Search", "risk_level": "High"},
    {"id": 6, "name": "ZabaSearch", "category": "Public Records", "risk_level": "High"},
    {"id": 7, "name": "FamilyTreeNow", "category": "Public Records", "risk_level": "High"},
    {"id": 8, "name": "Radaris", "category": "Public Records", "risk_level": "High"},
    {"id": 9, "name": "Zillow", "category": "Property Records", "risk_level": "Medium"},
    {"id": 10, "name": "Court Records", "category": "Legal Records", "risk_level": "High"},
    {"id": 11, "name": "LexisNexis", "category": "Legal Records", "risk_level": "High"},
    {"id": 12, "name": "OpenCorporates", "category": "Business Records", "risk_level": "Medium"},
    {"id": 13, "name": "LinkedIn", "category": "Professional", "risk_level": "Low"},
    {"id": 14, "name": "Facebook", "category": "Social", "risk_level": "Medium"},
    {"id": 15, "name": "Instagram", "category": "Social", "risk_level": "Medium"},
    {"id": 16, "name": "ZoomInfo", "category": "Business Data", "risk_level": "High"},
    {"id": 17, "name": "Clearbit", "category": "Business Data", "risk_level": "High"},
    {"id": 18, "name": "Yellow Pages", "category": "Business Listings", "risk_level": "Medium"},
    {"id": 19, "name": "Google My Business", "category": "Business Listings", "risk_level": "Medium"},
    {"id": 20, "name": "Yelp", "category": "Business Listings", "risk_level": "Low"},
]

@app.route('/api/brokers')
def get_brokers():
    return jsonify({'success': True, 'count': len(DATA_BROKERS), 'brokers': DATA_BROKERS})

@app.route('/api/security/scan', methods=['POST'])
def scan():
    return jsonify({'success': True, 'results': {'breaches': random.randint(0, 10)}})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
