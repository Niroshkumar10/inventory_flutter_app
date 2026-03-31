import { onCall, HttpsError } from "firebase-functions/v2/https";
import axios from "axios";
import * as dotenv from "dotenv";

dotenv.config();

export const sarvamSTT = onCall(async (request) => {
  try {
    const audioBase64 = request.data.audio;

    const response = await axios.post(
      "https://api.sarvam.ai/v1/speech-to-text",
      {
        audio: audioBase64,
        language: "en-IN",
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