import { onCall, HttpsError } from "firebase-functions/v2/https";
import axios from "axios";
import * as dotenv from "dotenv";

dotenv.config();

export const sarvamTTS = onCall(async (request) => {
  try {
    const text = request.data.text;

    const response = await axios.post(
      "https://api.sarvam.ai/v1/text-to-speech",
      {
        text: text,
        voice: "female_en",
      },
      {
        headers: {
          Authorization: `Bearer ${process.env.SARVAM_API_KEY}`,
          "Content-Type": "application/json",
        },
      }
    );

    return response.data;
  } catch (error: any) {
    throw new HttpsError("internal", error.message);
  }
});