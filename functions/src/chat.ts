
import * as functions from "firebase-functions";
import axios from "axios";

export const chatWithSarvam = functions.https.onRequest(
  async (req, res) => {
    try {
      const message = req.body.message;

      const response = await axios.post(
        "https://api.sarvam.ai/v1/chat/completions",
        {
          messages: [{ role: "user", content: message }],
        },
        {
          headers: {
            "Authorization": `Bearer ${process.env.SARVAM_API_KEY}`,
            "Content-Type": "application/json",
          },
        }
      );

      res.json(response.data);
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }
);