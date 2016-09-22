struct VerasonicsFrame {
   1: i32 identifier;
   2: i64 timestamp;
   3: string description;
   4: double lens_correction;
   5: double center_frequency;
   6: i32 number_of_channels;
   7: i32 number_of_samples_per_channel;
   16: binary channel_data;
}
