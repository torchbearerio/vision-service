import traceback
from io import BytesIO
from pythoncore import Task, Constants
from pythoncore.AWS import AWSClient
from pythoncore.Model.Landmark import Landmark
from pythoncore.Model.Hit import Hit
from pythoncore.Model import TorchbearerDB
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from PIL import Image
import numpy as np
import cv2
import os
import uuid
from ML.scoreImage import score_image


class VisionTask (Task.Task):

    def __init__(self, ep_id, hit_id, task_token):
        super(VisionTask, self).__init__(ep_id, hit_id, task_token)

    def _run_vision_task(self):
        # Create DB session
        session = TorchbearerDB.Session()

        try:
            for position in Constants.LANDMARK_POSITIONS.values():
                if AWSClient.s3_key_exists(Constants.S3_BUCKETS['SALIENCY_MAPS'],
                                           "{}_{}.json".format(self.hit_id, position)):

                    # Get streetview image for this Hit's ExecutionPoint
                    img = self._read_streetview_img_from_s3(position)

                    # Run object detection
                    detections = score_image(img)

                    # loop over detected objects, creating landmarks from them
                    for region in detections:
                        x1 = region['x1']
                        x2 = region['x2']
                        y1 = region['y1']
                        y2 = region['y2']
                        description = region['label']
                        visual_saliency_score = region['score']

                        if os.environ.get('debug'):
                            cv2.imshow("Output", img[y1:y2, x1:x2])
                            cv2.waitKey(0)

                        landmark = {
                            'id': uuid.uuid1(),
                            'description': description,
                            'rect': {'x1': x1, 'x2': x2, 'y1': y1, 'y2': y2},
                            'position': position,
                            'visual_saliency_score': visual_saliency_score
                        }

                        # Insert candidate landmark into DB
                        self._insert_candidate_landmark(landmark, session)

            # Commit DB inserts
            session.commit()

            self.send_success()

        except Exception as e:
            traceback.print_exc()
            self.send_failure('OBJECT_DETECTION_ERROR', e.message)

    def run(self):
        self._run_vision_task()

    def _read_streetview_img_from_s3(self, position):
        client = AWSClient.get_client('s3')
        response = client.get_object(
            Bucket=Constants.S3_BUCKETS['STREETVIEW_IMAGES'],
            Key="{}_{}.jpg".format(self.ep_id, position)
        )
        img = Image.open(response['Body'])
        # img.show()
        img = np.array(img)
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
        return img

    def _insert_candidate_landmark(self, candidate, session):
        landmark = Landmark.Landmark(
            landmark_id=candidate['id'],
            hit_id=self.hit_id,
            visual_saliency_score=candidate['visual_saliency_score'],
            position=candidate['position']
        )
        landmark.set_rect(candidate['rect'])

        session.add(landmark)

if __name__ == '__main__':
    sn = VisionTask(21, 6, "qwd")
    sn.run()
