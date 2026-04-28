from flask import Flask, render_template, request, jsonify
import json
import os
import re
from collections import defaultdict

class ChatDataProcessor:
    def __init__(self):
        self.dialogues = []
    
    def load_from_json(self, file_path):
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        self.dialogues = data
    
    def load_qq_export(self, file_path):
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        messages = []
        lines = content.split('\n')
        current_talker = None
        current_content = []
        
        for line in lines:
            match = re.match(r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] ([^:]+): (.*)$', line)
            if match:
                if current_talker and current_content:
                    messages.append({
                        'time': match.group(1),
                        'talker': current_talker,
                        'content': '\n'.join(current_content).strip()
                    })
                current_talker = match.group(2)
                current_content = [match.group(3)]
            elif current_talker:
                current_content.append(line)
        
        if current_talker and current_content:
            messages.append({
                'time': '',
                'talker': current_talker,
                'content': '\n'.join(current_content).strip()
            })
        
        self.dialogues = messages
    
    def create_training_pairs(self, your_name='我'):
        pairs = []
        for i in range(len(self.dialogues) - 1):
            current = self.dialogues[i]
            next_msg = self.dialogues[i + 1]
            
            if current['talker'] != your_name and next_msg['talker'] == your_name:
                pairs.append({
                    'input': current['content'],
                    'output': next_msg['content']
                })
        
        return pairs

class SimpleChatBot:
    def __init__(self):
        self.pairs = []
        self.responses_by_keyword = defaultdict(list)
    
    def train(self, pairs):
        self.pairs = pairs
        for pair in pairs:
            keywords = self.extract_keywords(pair['input'])
            for keyword in keywords:
                self.responses_by_keyword[keyword].append(pair['output'])
    
    def extract_keywords(self, text):
        text = text.lower()
        keywords = []
        for word in text:
            if word.isalpha() or '\u4e00' <= word <= '\u9fff':
                keywords.append(word)
        return keywords[:5]
    
    def predict(self, input_text, top_n=1):
        input_text = input_text.lower()
        scores = defaultdict(list)
        
        for pair in self.pairs:
            similarity = self.calculate_similarity(input_text, pair['input'])
            if similarity > 0:
                scores[similarity].append(pair['output'])
        
        if not scores:
            return ["嗯，这个问题我还不太清楚呢~"]
        
        sorted_scores = sorted(scores.keys(), reverse=True)
        results = []
        for score in sorted_scores:
            results.extend(scores[score])
            if len(results) >= top_n:
                break
        
        return results[:top_n]
    
    def calculate_similarity(self, text1, text2):
        text1, text2 = text1.lower(), text2.lower()
        words1 = set(text1)
        words2 = set(text2)
        if not words1 or not words2:
            return 0
        return len(words1 & words2) / len(words1 | words2)

processor = ChatDataProcessor()
if os.path.exists('sample_chat_data.json'):
    processor.load_from_json('sample_chat_data.json')
else:
    sample_data = [
        {"time": "2024-01-15 10:30:00", "talker": "朋友A", "content": "今天天气怎么样？"},
        {"time": "2024-01-15 10:31:00", "talker": "我", "content": "今天天气很好啊，阳光明媚的"},
        {"time": "2024-01-15 10:32:00", "talker": "朋友A", "content": "那我们下午去公园玩吧"},
        {"time": "2024-01-15 10:33:00", "talker": "我", "content": "好啊，下午三点在公园门口见"},
        {"time": "2024-01-15 14:00:00", "talker": "朋友B", "content": "最近在忙什么呢？"},
        {"time": "2024-01-15 14:05:00", "talker": "我", "content": "最近在学习Python编程，挺有意思的"},
        {"time": "2024-01-15 14:06:00", "talker": "朋友B", "content": "Python难不难学啊？"},
        {"time": "2024-01-15 14:10:00", "talker": "我", "content": "入门挺简单的，语法很直观，就是深入学习需要花时间"},
        {"time": "2024-01-16 09:00:00", "talker": "同事C", "content": "周末有什么安排吗？"},
        {"time": "2024-01-16 09:05:00", "talker": "我", "content": "周末打算在家看书，放松一下"},
        {"time": "2024-01-16 09:06:00", "talker": "同事C", "content": "看什么书呢？"},
        {"time": "2024-01-16 09:10:00", "talker": "我", "content": "正在看《Python编程从入门到实践》"},
        {"time": "2024-01-17 15:00:00", "talker": "朋友D", "content": "晚上一起吃饭吗？"},
        {"time": "2024-01-17 15:05:00", "talker": "我", "content": "好啊，想吃什么？"},
        {"time": "2024-01-17 15:06:00", "talker": "朋友D", "content": "火锅怎么样？"},
        {"time": "2024-01-17 15:10:00", "talker": "我", "content": "太好了，我最喜欢吃火锅了！"},
        {"time": "2024-01-18 11:00:00", "talker": "同学E", "content": "最近工作顺利吗？"},
        {"time": "2024-01-18 11:05:00", "talker": "我", "content": "还不错，项目进展很顺利"},
        {"time": "2024-01-18 11:06:00", "talker": "同学E", "content": "那就好，加油！"},
        {"time": "2024-01-18 11:10:00", "talker": "我", "content": "谢谢，你也是！"},
        {"time": "2024-01-19 16:00:00", "talker": "家人", "content": "晚上早点回家吃饭"},
        {"time": "2024-01-19 16:05:00", "talker": "我", "content": "好的，知道了"},
        {"time": "2024-01-20 10:00:00", "talker": "朋友F", "content": "推荐一部好看的电影吧"},
        {"time": "2024-01-20 10:05:00", "talker": "我", "content": "最近看了《流浪地球2》，挺不错的"},
        {"time": "2024-01-20 10:06:00", "talker": "朋友F", "content": "是科幻片吗？"},
        {"time": "2024-01-20 10:10:00", "talker": "我", "content": "是的，国产科幻片的天花板"},
        {"time": "2024-01-21 09:00:00", "talker": "朋友G", "content": "早上好！"},
        {"time": "2024-01-21 09:01:00", "talker": "我", "content": "早上好！今天天气不错"},
        {"time": "2024-01-21 09:02:00", "talker": "朋友G", "content": "今天有什么计划？"},
        {"time": "2024-01-21 09:05:00", "talker": "我", "content": "上午处理工作，下午学习新东西"},
        {"time": "2024-01-22 14:00:00", "talker": "朋友H", "content": "你会弹吉他吗？"},
        {"time": "2024-01-22 14:05:00", "talker": "我", "content": "会一点，业余爱好"},
        {"time": "2024-01-22 14:06:00", "talker": "朋友H", "content": "真厉害！"},
        {"time": "2024-01-22 14:10:00", "talker": "我", "content": "谢谢，就是平时自娱自乐"}
    ]
    with open('sample_chat_data.json', 'w', encoding='utf-8') as f:
        json.dump(sample_data, f, ensure_ascii=False, indent=2)
    processor.dialogues = sample_data

pairs = processor.create_training_pairs(your_name='我')
bot = SimpleChatBot()
bot.train(pairs)

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/chat', methods=['POST'])
def chat():
    data = request.get_json()
    message = data.get('message', '')
    response = bot.predict(message)[0]
    return jsonify({'response': response})

@app.route('/api/load_data', methods=['POST'])
def load_data():
    if 'file' not in request.files:
        return jsonify({'error': '没有选择文件'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': '文件名不能为空'}), 400
    
    if file.filename.endswith('.json'):
        content = file.read().decode('utf-8')
        try:
            data = json.loads(content)
            processor.dialogues = data
            pairs = processor.create_training_pairs(your_name='我')
            bot.train(pairs)
            return jsonify({'success': True, 'message': f'已加载 {len(data)} 条消息，生成 {len(pairs)} 对问答数据'})
        except:
            return jsonify({'error': 'JSON格式错误'}), 400
    
    elif file.filename.endswith('.txt'):
        content = file.read().decode('utf-8')
        processor.load_qq_export_from_content(content)
        pairs = processor.create_training_pairs(your_name='我')
        bot.train(pairs)
        return jsonify({'success': True, 'message': f'已加载 {len(processor.dialogues)} 条消息，生成 {len(pairs)} 对问答数据'})
    
    return jsonify({'error': '不支持的文件格式'}), 400

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
