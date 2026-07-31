import os
from PIL import Image
from pydub import AudioSegment

class Utils:
    @staticmethod
    def toWav(id, output_path=None):
        input_path = f"./tmp/{id}.mp3"

        if not os.path.exists(input_path):
            raise FileNotFoundError(f"Input MP3 file not found: {input_path}")
            
        if output_path is None:
            output_path = os.path.splitext(input_path)[0] + '.wav'
            
        audio = AudioSegment.from_mp3(input_path)
        audio.export(output_path, format='wav')

    @staticmethod
    def toJpg(id):
        png_path = f"./tmp/{id}.png"
        jpg_path = f"./tmp/{id}.jpg"
        
        if not os.path.exists(png_path):
            raise FileNotFoundError(f"Input PNG file not found: {png_path}")

        try:
            with Image.open(png_path) as img:
                rgb_img = img.convert('RGB')
                rgb_img.save(jpg_path, 'JPEG', quality=95)
            print(f"Success: {png_path} converted to {jpg_path}")
        except Exception as e:
            print(f"An error occurred during image conversion: {e}")
            raise e

