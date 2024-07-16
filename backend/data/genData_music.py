import pandas as pd
import numpy as np

num_rows = 1000

df = pd.DataFrame({
    'Spotify Streams': np.random.randint(10000, 10000000, size = num_rows),
    'Spotify Playlist Count': np.random.randint(1, 1000, size = num_rows),
    'Youtube Likes': np.random.randint(1000, 500000, size = num_rows),
    'TikTok Likes': np.random.randint(1000, 500000, size = num_rows),
    'Apple Music Playlist Count': np.random.randint(1, 1000, size = num_rows),
    'Amazon Playlist Count': np.random.randint(1, 1000, size = num_rows),
    'Explicit Track': np.random.choice(['Yes', 'No'], size = num_rows)
})

df.to_csv('explicit_music.csv', index = False)