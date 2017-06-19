from pythoncore import Constants, WorkerService
from VisionTask import VisionTask


def handle_task(task_input, task_token):
    ep_id = task_input["epId"]
    hit_id = task_input["hitId"]
    lm = VisionTask(ep_id, hit_id, task_token)
    lm.run()

if __name__ == '__main__':
    # handle_task({"epId": 1000, "hitId": 57}, "adsf")

    thisTask = Constants.TASK_ARNS['CV_DESCRIPTION']

    WorkerService.start((thisTask, handle_task))
